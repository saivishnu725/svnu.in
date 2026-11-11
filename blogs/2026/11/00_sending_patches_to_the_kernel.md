<!-- series: open source contributions -->

# 00 - sending patches to the kernel

## abstract

i have been sending small fixes to open source projects for a while now. they live in random corners of the internet (github, mailing lists, someone's issue tracker) and i keep forgetting what i did and where. so this is me putting them in one place.

i am splitting it into two posts. this one is the kernel side of things. the [[01_small_fixes_on_github|next one]] is everything that went through github.

before you get excited, none of these are big. one of them is literally one line of a comment. but each one taught me how a project actually takes code from a random person on the internet, and that was the whole point.

the kernel does not do pull requests. you write a patch, you email it to a mailing list, and people reply to your email. like it's 2003. i wanted to learn that, so i went looking for the smallest thing i could fix.

## 00 rust for linux

### 00.a - the issue

[Rust-for-Linux](https://rust-for-linux.com/) keeps a bunch of "good first issue" tickets on github. [#1167](https://github.com/Rust-for-Linux/linux/issues/1167) was one of them. the doc comment on `IoMem` in `rust/kernel/io.rs` looked like this:

```rust
/// IO-mapped memory, starting at the base address @addr and spanning @maxlen bytes.
```

two things wrong with it.

1. `@addr` is how you point at a parameter in C kernel-doc. rust docs don't do that.
2. `addr` and `maxlen` are private fields. anyone reading the generated docs can't see them, so the sentence means nothing to them.

### 00.b - the fix

```diff
-/// IO-mapped memory, starting at the base address @addr and spanning @maxlen bytes.
+/// IO-mapped memory region.
```

yep. that's it. that's the patch.

### 00.c - the actual work

the one line took a minute. everything around it took way longer. the issue itself spells out what they expect: a proper commit title, signing off under the Developer's Certificate of Origin, the right tags, testing the docs build. the [submitting patches](https://docs.kernel.org/process/submitting-patches.html) doc and the [rust-for-linux contributing](https://rust-for-linux.com/contributing) page cover the rest.

the flow, roughly:

1. make the change and commit with `git commit -s` (the `-s` adds your `Signed-off-by` line)
2. run `./scripts/checkpatch.pl` on it so you don't embarrass yourself
3. run `./scripts/get_maintainer.pl` to find out who should get the email
4. `git format-patch` then `git send-email`

this is the part i actually wanted to learn. github hides all of this behind a green button.

### 00.d - what happened

[the patch](https://lore.kernel.org/rust-for-linux/20250602164923.48893-2-saivishnu725@gmail.com/) got a `Reviewed-by` from Benno Lossin and Miguel Ojeda picked it up. he reworded the title to `rust: io: avoid mentioning private fields in IoMem` and fixed up my tags. so my commit title was not good enough lol. noted.

it's in mainline now as [`0303584766b7`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=0303584766b7bdb6564c7e8f13e0b59b6ef44984).

my name is in the linux kernel `git log`. for one line of a doc comment. i'll take it.

## 01 linux media (v4l-utils)

### 01.a - the problem

[v4l-utils](https://git.linuxtv.org/v4l-utils.git) is the userspace side of video4linux, the stuff that talks to webcams, capture cards, tv tuners and so on. one of the tools in there is `v4l2-sysfs-path`. it goes through your media devices and tells you which video, audio and other nodes belong to the same piece of hardware.

i only know that because i read the source. if you run `v4l2-sysfs-path --help` you get the list of flags and the version. nothing about WHAT the program is for.

it uses `argp` for argument parsing. this is what the struct looked like:

```c
static struct argp argp = {
	.options = options,
	.parser = parse_opt,
};
```

argp has a `doc` field for exactly this. it just wasn't being used.

### 01.b - the fix

i added a help message to `v4l2-sysfs-path/v4l2-sysfs-path.c` so `--help` actually tells you what the tool does before dumping the flags on you.

<!-- TODO: paste the diff from the patch here -->

this one went to the linux-media list. same email workflow as before, different subsystem, different maintainers. second time around it felt a lot less scary.

the patch is [here](https://lore.kernel.org/linux-media/20260623162403.21641-1-saivishnu725@gmail.com/).

<!-- TODO: update with status once it gets picked up / reviewed -->

## disclaimer

neither of these is real kernel development. one is a doc comment and the other is a help string in a userspace tool. i know. but the hard part for me was never the code, it was figuring out how to get it in front of the right people in the right format. that part i now (kind of) know.

see you in the next one: [[01_small_fixes_on_github|01 - small fixes on github]].

laters!
svnu©️ 06-November-2026 10:56
