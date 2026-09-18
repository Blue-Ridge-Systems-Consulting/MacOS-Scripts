#define _GNU_SOURCE
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <signal.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/inotify.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#define APP "northstar-guard"
#define MAX_WATCHES 4096
#define EVENT_BUF (64 * 1024)

typedef struct { int wd; char path[PATH_MAX]; } Watch;
static Watch watches[MAX_WATCHES];
static size_t watch_count;
static volatile sig_atomic_t keep_running = 1;
static unsigned scanned, clean_count, finding_count, trusted_count, error_count;

static const char *home_dir(void) {
    const char *h = getenv("HOME");
    return h && *h ? h : "/tmp";
}

static const char *data_root(void) {
    const char *d = getenv("NORTHSTAR_DATA");
    if (d && *d) return d;
    /* A root/system invocation on a server should use the service data area. */
    if (geteuid() == 0) return "/var/lib/northstar-guard";
    return NULL;
}

static void dirs(char *data, size_t n, const char *suffix) {
    const char *root = data_root();
    if (root) snprintf(data, n, "%s/%s", root, suffix);
    else snprintf(data, n, "%s/.local/share/northstar-guard/%s", home_dir(), suffix);
}

static void ensure_dirs(void) {
    char p[PATH_MAX];
    dirs(p, sizeof p, "");
    mkdir(p, 0700);
    dirs(p, sizeof p, "reports");
    mkdir(p, 0700);
}

static void timestamp(char *out, size_t n, const char *fmt) {
    time_t now = time(NULL); struct tm t;
    localtime_r(&now, &t); strftime(out, n, fmt, &t);
}

static void log_line(const char *fmt, ...) {
    char p[PATH_MAX], ts[64]; va_list ap;
    dirs(p, sizeof p, "events.log");
    FILE *f = fopen(p, "a"); if (!f) return;
    timestamp(ts, sizeof ts, "%Y-%m-%d %H:%M:%S %Z");
    fprintf(f, "[%s] ", ts); va_start(ap, fmt); vfprintf(f, fmt, ap); va_end(ap); fputc('\n', f); fclose(f);
}

static char *shell_quote(const char *s) {
    size_t len = 3; for (const char *p=s; *p; p++) len += (*p=='\'') ? 4 : 1;
    char *q = malloc(len); if (!q) return NULL; char *o=q; *o++='\'';
    for (const char *p=s; *p; p++) { if (*p=='\'') { memcpy(o, "'\\''", 4); o+=4; } else *o++=*p; }
    *o++='\''; *o='\0'; return q;
}

static char *capture(const char *fmt, ...) {
    char cmd[PATH_MAX*3]; va_list ap; va_start(ap, fmt); vsnprintf(cmd, sizeof cmd, fmt, ap); va_end(ap);
    FILE *p = popen(cmd, "r"); if (!p) return strdup("");
    size_t cap=4096, len=0; char *out=malloc(cap); if (!out) { pclose(p); return strdup(""); }
    out[0]='\0'; char buf[1024];
    while (fgets(buf, sizeof buf, p)) { size_t m=strlen(buf); if (len+m+1>cap) { cap*=2; char *x=realloc(out,cap); if(!x){free(out);pclose(p);return strdup("");} out=x; } memcpy(out+len,buf,m); len+=m; out[len]='\0'; }
    pclose(p); return out;
}

static char *sha256(const char *path) {
    char *q=shell_quote(path); if (!q) return strdup("");
    char *raw=capture("sha256sum -- %s 2>/dev/null", q); free(q);
    char *sp=strchr(raw,' '); if (sp) *sp='\0';
    char *nl=strchr(raw,'\n'); if (nl) *nl='\0'; return raw;
}

static bool is_trusted(const char *path, const char *hash) {
    char p[PATH_MAX]; dirs(p,sizeof p,"trusted.tsv"); FILE *f=fopen(p,"r"); if(!f) return false;
    char line[PATH_MAX+100]; bool yes=false;
    while(fgets(line,sizeof line,f)){ char *tab=strchr(line,'\t'); if(!tab) continue; *tab='\0'; char *nl=strchr(tab+1,'\n'); if(nl)*nl='\0'; if(!strcmp(line,hash)&&!strcmp(tab+1,path)){yes=true;break;} }
    fclose(f); return yes;
}

static int trust_path(const char *path, bool remove) {
    struct stat st; if(stat(path,&st)||!S_ISREG(st.st_mode)){fprintf(stderr,"Not a regular file: %s\n",path);return 1;}
    char p[PATH_MAX]; dirs(p,sizeof p,"trusted.tsv"); char *hash=sha256(path); if(!hash||!*hash){free(hash);return 1;}
    FILE *in=fopen(p,"r"); char tmp[PATH_MAX]; snprintf(tmp,sizeof tmp,"%s.tmp",p); FILE *out=fopen(tmp,"w"); if(!out){free(hash);if(in)fclose(in);return 1;}
    char line[PATH_MAX+100]; bool found=false;
    if(in){while(fgets(line,sizeof line,in)){char copy[sizeof line];strncpy(copy,line,sizeof copy);copy[sizeof copy-1]=0;char *tab=strchr(copy,'\t');if(tab){*tab='\0';char *nl=strchr(tab+1,'\n');if(nl)*nl='\0';if(!strcmp(tab+1,path)){found=true;if(remove)continue;}}fputs(line,out);}fclose(in);}
    if(!remove&&!found)fprintf(out,"%s\t%s\n",hash,path); fclose(out); if(rename(tmp,p)){unlink(tmp);free(hash);return 1;}
    printf("%s %s: %s\n",remove?"Untrusted":"Trusted",path,remove?"removed":"added"); free(hash); return 0;
}

static void record_finding(const char *engine, const char *path, const char *detail) {
    char p[PATH_MAX], ts[64]; dirs(p,sizeof p,"findings.tsv"); FILE *f=fopen(p,"a"); if(!f)return;
    timestamp(ts,sizeof ts,"%Y-%m-%dT%H:%M:%S%z"); fprintf(f,"%s\t%s\t%s\t%s\n",ts,engine,path,detail&&*detail?detail:"detected"); fclose(f);
    finding_count++; log_line("finding engine=%s path=%s detail=%s",engine,path,detail&&*detail?detail:"detected");
}

static bool scan_file(const char *path, bool verbose) {
    struct stat st; if(stat(path,&st)||!S_ISREG(st.st_mode)) return true;
    char *hash=sha256(path); scanned++;
    if(hash&&is_trusted(path,hash)){trusted_count++;if(verbose)printf("TRUSTED %s\n",path);free(hash);return true;} free(hash);
    char *q=shell_quote(path); if(!q){error_count++;return false;}
    /* Keep a malformed or very large input from holding the live monitor. */
    char *clam=capture("timeout 45s clamscan --infected --no-summary --stdout --max-filesize=25976319 --max-scansize=51952638 -- %s 2>/dev/null",q);
    bool bad=false; if(clam&&*clam){record_finding("ClamAV",path,clam);bad=true;}
    char rules[PATH_MAX]; dirs(rules,sizeof rules,"rules/northstar.yar"); char *rq=shell_quote(rules);
    char *yara=rq?capture("yara -w -r %s -- %s 2>/dev/null",rq,q):strdup("");
    if(yara&&*yara){record_finding("YARA",path,yara);bad=true;}
    free(rq);free(clam);free(yara);free(q); if(bad){if(verbose)printf("FINDING %s\n",path);}else{clean_count++;if(verbose)printf("CLEAN %s\n",path);} return !bad;
}

static void scan_tree(const char *root, bool verbose) {
    struct stat st; if(lstat(root,&st)) {error_count++;return;}
    if(S_ISREG(st.st_mode)){scan_file(root,verbose);return;} if(!S_ISDIR(st.st_mode))return;
    DIR *d=opendir(root);if(!d){error_count++;return;} struct dirent *e; char p[PATH_MAX];
    while((e=readdir(d))){if(!strcmp(e->d_name,".")||!strcmp(e->d_name,".."))continue; if(!strcmp(e->d_name,".git"))continue;
        if(snprintf(p,sizeof p,"%s/%s",root,e->d_name)>= (int)sizeof p){error_count++;continue;} scan_tree(p,verbose);
    } closedir(d);
}

static void quick_roots(char roots[][PATH_MAX], size_t *n, bool full) {
    *n=0;
    const char *spec = getenv("NORTHSTAR_WATCH_ROOTS");
    if (spec && *spec) {
        char *copy = strdup(spec), *save = NULL;
        for (char *tok = copy ? strtok_r(copy, ":", &save) : NULL;
             tok && *n < 24; tok = strtok_r(NULL, ":", &save)) {
            if (*tok) snprintf(roots[(*n)++], PATH_MAX, "%s", tok);
        }
        free(copy);
    }
    if (*n == 0) {
        const char *h=home_dir(); const char *rel[]={"Downloads","Desktop","Documents",".config/autostart"};
        for(size_t i=0;i<sizeof(rel)/sizeof(rel[0]);i++)snprintf(roots[(*n)++],PATH_MAX,"%s/%s",h,rel[i]);
    }
    if(full){
        const char *sys[]={"/tmp","/var/tmp","/usr/local/bin","/usr/local/sbin","/etc/systemd/system","/etc/cron.d","/etc/cron.daily","/etc/xdg/autostart"};
        for(size_t i=0;i<sizeof(sys)/sizeof(sys[0]) && *n<24;i++){
            bool seen=false; for(size_t j=0;j<*n;j++) if(!strcmp(roots[j],sys[i])) {seen=true;break;}
            if(!seen) snprintf(roots[(*n)++],PATH_MAX,"%s",sys[i]);
        }
    }
}

static int run_scan(bool full, const char *one) {
    ensure_dirs(); scanned=clean_count=finding_count=trusted_count=error_count=0; char roots[24][PATH_MAX]; size_t n=0;
    char report[PATH_MAX], ts[64]; timestamp(ts,sizeof ts,"%Y-%m-%d-%H%M%S"); dirs(report,sizeof report,"reports"); size_t used=strlen(report); snprintf(report+used,sizeof(report)-used,"/%s-%s-scan.md",ts,one?"path":(full?"full":"quick"));
    FILE *f=fopen(report,"w"); if(!f){perror(report);return 1;} fprintf(f,"# Northstar Guard %s scan\n\n- Generated: %s\n- Scope: **%s**\n- Engines: ClamAV and YARA\n- Live monitor: unaffected\n\n",one?"Path":(full?"Full":"Quick"),ts,one?one:(full?"main system areas":"user download and persistence areas")); fclose(f);
    if(one)scan_tree(one,true);else{quick_roots(roots,&n,full);for(size_t i=0;i<n;i++){printf("Scanning %s\n",roots[i]);scan_tree(roots[i],true);}}
    f=fopen(report,"a");if(f){fprintf(f,"## Executive summary\n\nScanned **%u** files. **%u** findings, **%u** trusted exclusions, and **%u** inaccessible or skipped paths were recorded.\n\n",scanned,finding_count,trusted_count,error_count);fprintf(f,"## Result\n\n%s\n",finding_count?"Review the findings listed in the local findings log before taking action.":"No detections were reported by the enabled engines.");fclose(f);} printf("Report: %s\n",report); return finding_count?2:0;
}

static void write_status(const char *state) { char p[PATH_MAX];dirs(p,sizeof p,"status");FILE*f=fopen(p,"w");if(f){fprintf(f,"%s\n",state);fclose(f);}}

static void sig_stop(int sig){(void)sig;keep_running=0;}

static void add_watch(int fd,const char *path) {
    if(watch_count>=MAX_WATCHES)return; int wd=inotify_add_watch(fd,path,IN_CLOSE_WRITE|IN_MOVED_TO|IN_CREATE|IN_DELETE_SELF|IN_MOVE_SELF);if(wd<0)return;
    watches[watch_count].wd=wd;snprintf(watches[watch_count].path,PATH_MAX,"%s",path);watch_count++;
}

static void add_watch_recursive(int fd,const char *root) {
    struct stat st;if(lstat(root,&st)||!S_ISDIR(st.st_mode))return;add_watch(fd,root);DIR*d=opendir(root);if(!d)return;struct dirent*e;char p[PATH_MAX];
    while((e=readdir(d))){if(!strcmp(e->d_name,".")||!strcmp(e->d_name,"..")||!strcmp(e->d_name,".git"))continue;if(snprintf(p,sizeof p,"%s/%s",root,e->d_name)>= (int)sizeof p)continue;add_watch_recursive(fd,p);}closedir(d);
}

static const char *watch_path(int wd){for(size_t i=0;i<watch_count;i++)if(watches[i].wd==wd)return watches[i].path;return NULL;}

static int daemon_run(void) {
    ensure_dirs(); int fd=inotify_init1(0);if(fd<0){perror("inotify");return 1;} char roots[8][PATH_MAX];size_t n=0;quick_roots(roots,&n,false);for(size_t i=0;i<n;i++)add_watch_recursive(fd,roots[i]);
    signal(SIGTERM,sig_stop);signal(SIGINT,sig_stop);write_status("running");log_line("live monitor started watches=%zu",watch_count);char buf[EVENT_BUF];
    while(keep_running){ssize_t len=read(fd,buf,sizeof buf);if(len<0){if(errno==EINTR)continue;perror("inotify");break;}for(char*p=buf;p<buf+len;){struct inotify_event*e=(struct inotify_event*)p;const char*base=watch_path(e->wd);if(base&&e->len&&!(e->mask&IN_ISDIR)&&(e->mask&(IN_CLOSE_WRITE|IN_MOVED_TO))){char path[PATH_MAX];snprintf(path,sizeof path,"%s/%s",base,e->name);scan_file(path,false);}else if(base&&(e->mask&IN_ISDIR)&&(e->mask&IN_CREATE)){char path[PATH_MAX];snprintf(path,sizeof path,"%s/%s",base,e->name);add_watch_recursive(fd,path);}p+=sizeof(struct inotify_event)+e->len;}}
    write_status("stopped");log_line("live monitor stopped");close(fd);return 0;
}

static void print_findings(void){char p[PATH_MAX];dirs(p,sizeof p,"findings.tsv");FILE*f=fopen(p,"r");if(!f){puts("No findings recorded.");return;}char line[PATH_MAX+200];while(fgets(line,sizeof line,f))fputs(line,stdout);fclose(f);}
static void print_status(void){char p[PATH_MAX],buf[64]={0};dirs(p,sizeof p,"status");FILE*f=fopen(p,"r");if(f){fgets(buf,sizeof buf,f);fclose(f);}printf("Northstar Guard live monitor: %s",*buf?buf:"unknown\n");}
static int start_stop(bool start){
    char svc[PATH_MAX]; snprintf(svc,sizeof svc,"northstar-guard.service");
    bool system = geteuid() == 0 || (getenv("NORTHSTAR_SYSTEM_SERVICE") && *getenv("NORTHSTAR_SYSTEM_SERVICE"));
    char *out = system ? capture("systemctl %s %s 2>&1",start?"start":"stop",svc)
                       : capture("systemctl --user %s %s 2>&1",start?"start":"stop",svc);
    if(out){fputs(out,stdout);free(out);} return 0;
}

int main(int argc,char **argv){ensure_dirs();if(argc>1&&!strcmp(argv[1],"--daemon"))return daemon_run();if(argc<2){fprintf(stderr,"Usage: %s status|start|stop|scan|findings|trust\n",APP);return 2;}
    if(!strcmp(argv[1],"status")){print_status();return 0;} if(!strcmp(argv[1],"start"))return start_stop(true);if(!strcmp(argv[1],"stop"))return start_stop(false);if(!strcmp(argv[1],"findings")){print_findings();return 0;}
    if(!strcmp(argv[1],"trust")&&argc>=4&&!strcmp(argv[2],"add"))return trust_path(argv[3],false);if(!strcmp(argv[1],"trust")&&argc>=4&&!strcmp(argv[2],"remove"))return trust_path(argv[3],true);if(!strcmp(argv[1],"trust")&&argc>=3&&!strcmp(argv[2],"list")){char p[PATH_MAX];dirs(p,sizeof p,"trusted.tsv");char *x=capture("cat -- %s 2>/dev/null",shell_quote(p));if(x){fputs(x,stdout);free(x);}return 0;}
    if(!strcmp(argv[1],"scan")){if(argc<3)return 2;if(!strcmp(argv[2],"quick"))return run_scan(false,NULL);if(!strcmp(argv[2],"full"))return run_scan(true,NULL);if(!strcmp(argv[2],"path")&&argc>=4)return run_scan(false,argv[3]);}
    fprintf(stderr,"Unknown command.\n");return 2;
}
