# 01 - small fixes on github

welcome back. last time was [[00_sending_patches_to_the_kernel|the kernel stuff]]. this one is the github side, which is a lot less email and a lot more green buttons.

both of these came from the same place. i was using the thing, it annoyed me (or broke), and i went and fixed it.

## 00 homebox

### 00.a - the problem

[homebox](https://github.com/sysadminsmedia/homebox) is a self hosted inventory app for your home. you log what you own, where it is, when you bought it, etc.

it lets you export everything as a csv. the file was always called `homebox-items.csv`. every single time. so if you export today and again next week, the new one just replaces the old one. i wanted to keep exports around locally and version them, and that doesn't really work when they all have the same name.

### 00.b - the fix

add the time to the filename. simple enough.

```diff
+		timestamp := time.Now().Format("2006-01-02_15-04-05") // YYYY-MM-DD_HH-MM-SS format
+		filename := fmt.Sprintf("homebox-items_%s.csv", timestamp) // add timestamp to filename

 		w.Header().Set("Content-Type", "text/csv")
-		w.Header().Set("Content-Disposition", "attachment;filename=homebox-items.csv")
+		w.Header().Set("Content-Disposition", fmt.Sprintf("attachment;filename=%s", filename))
```

this was my first PR to anything. ever. also my first time writing Go. i'm not going to pretend i knew what i was doing, the timestamp line came straight from StackOverflow (i even said so in the PR).

fun thing i learnt: Go doesn't use `%Y-%m-%d` like everyone else. you write out a reference date, `2006-01-02 15:04:05`, in the shape you want and it figures out the format from that. weird. kind of cool. still weird.

### 00.c - what happened

[#366](https://github.com/sysadminsmedia/homebox/pull/366) got merged the same day (2nd December 2024). exports now look like `homebox-items_2024-12-02_12-30-00.csv`.

## 01 proxmox VE helper scripts

### 01.a - the problem

[community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE) is a big collection of scripts that spin up LXC containers on Proxmox with an app already installed. you run one command and you have a container with the thing running in it.

the one for [Actual Budget](https://actualbudget.org/) was broken. it died here:

```bash
$STD npm install --location=global @actual-app/sync-server
```

`@actual-app/sync-server` depends on `better-sqlite3`, which is a native module. it gets compiled on install, which means it needs a C++ compiler. the script was only installing `make`.

### 01.b - the fix

```diff
 $STD apt-get install -y \
-  make
+  make \
+  g++
```

one dependency. that's the fix.

### 01.c - what happened

[#6293](https://github.com/community-scripts/ProxmoxVE/pull/6293) was merged in about 10 minutes (28th July 2025). a maintainer pushed a formatting commit on top of mine before merging, so apparently i can't even add one line without messing up the indentation. noted again.

## disclaimer

neither of these is impressive on its own. a timestamp and a compiler. but both got merged, and both are things that bugged me while using the software. that's the whole idea. use stuff, find what's broken, fix it, send it back.

that's it for now. more when i break more things.

laters!
svnu©️ 06-November-2026 10:56
