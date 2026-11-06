# Robot Framework Server Pre-Check: User Manual

A simple, generic Linux server pre-check built with Robot Framework. It verifies the server's **OS type, RAM, CPU, storage, bonds, interfaces, internet, DNS and NTP**. All settings live in one external file (`env.resource`), so the same test file works on any server and any environment.

---

## Table of Contents

1. [What it checks](#1-what-it-checks)
2. [Files and folder layout](#2-files-and-folder-layout)
3. [Requirements and installation](#3-requirements-and-installation)
4. [Configuration: env.resource](#4-configuration-envresource)
5. [How to run](#5-how-to-run)
6. [Reading the results](#6-reading-the-results)
7. [Test case reference](#7-test-case-reference)
8. [Common scenarios](#8-common-scenarios)
9. [Troubleshooting](#9-troubleshooting)
10. [How it works internally](#10-how-it-works-internally)

---

## 1. What it checks

| # | Area | Tag | Checks |
|---|------|-----|--------|
| 1 | OS type | `os` | Kernel is Linux and OS ID (ubuntu, rhel, ...) is in the allowed list |
| 2 | RAM | `ram` | Total RAM is at least the minimum (GB) |
| 3 | CPU | `cpu` | CPU core count is at least the minimum |
| 4 | Storage | `storage` | Each path has the minimum total size and is not fuller than the maximum % |
| 5 | Bond | `bond` | Bond exists |
| 6 | Bond configuration | `bond` | Mode (e.g. 802.3ad), number of NICs, MTU |
| 7 | Bond status | `bond` | Bond is up, every NIC in it is up, LACP partner (switch) negotiated |
| 8 | Interface | `interface` | Interface exists |
| 9 | Interface status | `interface` | Operational state is `up`, optional MTU check |
| 10 | Internet | `internet` | Test URL is reachable |
| 11 | DNS | `dns` | Each listed name resolves |
| 12 | NTP | `ntp` | Clock is synchronised, optional NTP server check |

**Generic by design**

- Nothing is hardcoded to a node name, role or IP.
- Leave a list empty in `env.resource` and that check is **skipped** (for example, a server with no bonds).
- Set a number to `0` (for example `BOND_MTU`) to switch that check off.

---

## 2. Files and folder layout

Keep both files in the same folder:

```
robot-precheck/
├── script.robot     # the test cases (do not edit for normal use)
└── env.resource       # all settings (edit this per server / environment)
```

After a run, Robot creates `output.xml`, `log.html` and `report.html` in the folder you ran from.

> If your test file has a different name, use that name in the commands below. Only `env.resource` must keep its name, because the test file imports it.

---

## 3. Requirements and installation

| Requirement | Needed for |
|-------------|-----------|
| Linux (Ubuntu, RHEL, Rocky, Alma, Debian ...) | everything |
| Python 3 | running Robot |
| Robot Framework **5.0 or newer** | the `IF`, `RETURN` and `Skip If` syntax used |
| `curl` | internet check |
| `getent` (standard on Linux) | DNS check with system resolver |
| `dig` (`dnsutils` / `bind-utils`) | only if you set `DNS_SERVER` |
| `timedatectl` (systemd) | NTP check |
| `chronyc` | only if you set `NTP_SERVER` |
| root / sudo | recommended; reading `/proc/net/bonding` is usually fine without it |

### Install Robot Framework

```bash
pip3 install robotframework
# or on Ubuntu with a restricted system Python:
pip3 install robotframework --break-system-packages
# or in a virtual environment:
python3 -m venv venv && source venv/bin/activate && pip install robotframework
```

Check the version:

```bash
robot --version
```

### Install optional tools

```bash
# Ubuntu / Debian
sudo apt install -y curl dnsutils chrony

# RHEL / Rocky / Alma
sudo dnf install -y curl bind-utils chrony
```

---

## 4. Configuration: env.resource

Edit **only** this file. The syntax is Robot "variables":

- `${NAME}   value` is a single value.
- `@{NAME}   a   b   c` is a list. Separate items with **two or more spaces** (or a tab).
- Text after two or more spaces and a `#` is a comment.

### Variable reference

| Variable | Type | Example | Meaning |
|----------|------|---------|---------|
| `ALLOWED_OS` | list | `ubuntu rhel rocky` | Allowed values of `ID=` in `/etc/os-release`. Empty = skip OS test |
| `MIN_CPU` | number | `4` | Minimum CPU cores |
| `MIN_RAM_GB` | number | `8` | Minimum RAM in GB |
| `STORAGE_PATHS` | list | `/  /var  /data` | Paths (filesystems) to check. Empty = skip storage tests |
| `MIN_STORAGE_GB` | number | `50` | Minimum total size of each path |
| `MAX_USED_PERCENT` | number | `85` | Fail if a path is more than this % full |
| `BONDS` | list | `bond0 bond1` | Bonds to check. Empty = skip all bond tests |
| `BOND_MODE` | text | `802.3ad` | Text that must appear in the bond's "Bonding Mode" line (`active-backup`, `balance-xor` ...) |
| `BOND_SLAVES` | number | `2` | Expected number of NICs in each bond |
| `BOND_MTU` | number | `9000` | Expected bond MTU. `0` = do not check |
| `INTERFACES` | list | `eno1 enp6s18 bond0.100` | **Extra** interfaces to check (bonds are added automatically). Empty = only bonds |
| `INTERFACE_MTU` | number | `9000` | Expected MTU for all checked interfaces. `0` = do not check |
| `INTERNET_URL` | text | `https://archive.ubuntu.com` | URL used for the internet test |
| `DNS_NAMES` | list | `google.com example.com` | Names that must resolve. Empty = skip |
| `DNS_SERVER` | text | `10.0.0.2` | Specific DNS server to query. Empty = system resolver |
| `NTP_SERVER` | text | `10.0.0.3` | Optional: must appear in `chronyc sources`. Empty = skip |

### Important rule about bonds and interfaces

Every bond listed in `BONDS` automatically gets the **Interface Exists** and **Interface Status Is Up** checks. Do **not** repeat bonds in `INTERFACES`. Use `INTERFACES` only for other things (physical NICs, VLANs, vNICs).

| You set | What is checked |
|---------|-----------------|
| `BONDS = bond0 bond1`, `INTERFACES` empty | bond0, bond1 only |
| `BONDS = bond0 bond1`, `INTERFACES = eno1` | bond0, bond1, eno1 |
| `BONDS` empty, `INTERFACES = eth0` | eth0 only (no bond tests) |
| Both empty | all bond and interface tests skipped |

### Example: server with 3 bonds, jumbo frames

```robot
@{BONDS}               bond0    bond1    bond2
${BOND_MODE}           802.3ad
${BOND_SLAVES}         2
${BOND_MTU}            9000
@{INTERFACES}
```

### Example: server with no bonds, two plain NICs

```robot
@{BONDS}
@{INTERFACES}          eno1    eno2
${INTERFACE_MTU}       1500
```

### Example: active-backup bond

```robot
@{BONDS}               bond0
${BOND_MODE}           active-backup
${BOND_SLAVES}         2
${BOND_MTU}            1500
```
(The LACP partner test is automatically skipped when the mode is not `802.3ad`.)

---

## 5. How to run

Open a terminal in the folder with the two files.

### Run everything

```bash
robot script.robot
```

or as root (recommended on servers):

```bash
sudo robot script.robot
```

### Run one area only (by tag)

```bash
robot --include os        script.robot
robot --include ram       script.robot
robot --include cpu       script.robot
robot --include storage   script.robot
robot --include bond      script.robot
robot --include interface script.robot
robot --include internet  script.robot
robot --include dns       script.robot
robot --include ntp       script.robot
```

### Run several areas

```bash
robot --include bond --include interface script.robot
robot --include internetORdnsORntp       script.robot
```

### Run one test by name

```bash
robot --test "Bond Status Is Up" script.robot
```

### Override a value without editing the file

```bash
robot -v MIN_RAM_GB:16 -v MIN_CPU:8 script.robot
robot -v DNS_SERVER:10.0.0.2 script.robot
```

### Put results in a separate folder

```bash
robot --outputdir results script.robot
```

### Name results by date and host

```bash
robot --outputdir results/$(hostname)-$(date +%F) script.robot
```

### Check the file is valid without running anything

```bash
robot --dryrun script.robot
```

### Use a different env file per environment

Keep copies such as `env.prod.resource` and `env.lab.resource`, then copy the one you want before running:

```bash
cp env.lab.resource env.resource && robot script.robot
```

### Run on many servers

Copy both files to each server (scp, Ansible, etc.) and run the same command. Example with SSH:

```bash
for h in node1 node2 node3; do
  scp script.robot env.resource $h:/tmp/precheck/
  ssh $h "cd /tmp/precheck && sudo robot --outputdir /tmp/precheck/out script.robot"
done
```

### Exit code (for automation)

| Exit code | Meaning |
|-----------|---------|
| `0` | all tests passed |
| `1` to `250` | number of failed tests |
| `252` | invalid test data / command line |

Example in a pipeline:

```bash
robot script.robot || echo "Pre-check FAILED"
```

---

## 6. Reading the results

### Console

```
RAM Is Enough                                                         | PASS |
Interface Exists                                                      | FAIL |
Interface bond2 not found
```

- **PASS** means the requirement is met.
- **FAIL** means it is not; the line below shows why.
- **SKIP** means the check was skipped because its list in `env.resource` is empty.

### Files

| File | Use |
|------|-----|
| `report.html` | Summary page: green = pass, red = fail. Share this |
| `log.html` | Detailed step-by-step log, with the exact commands and output |
| `output.xml` | Machine-readable results for other tools |

On a server without a browser, copy `report.html` and `log.html` to your laptop with `scp`.

---

## 7. Test case reference

| Test | Tag | Pass condition | Command used |
|------|-----|----------------|--------------|
| OS Type Is Allowed | `os` | `uname -s` is Linux and `ID` in `/etc/os-release` is in `ALLOWED_OS` | `uname -s`, `. /etc/os-release` |
| RAM Is Enough | `ram` | RAM GB >= `MIN_RAM_GB` | `awk` on `/proc/meminfo` |
| CPU Is Enough | `cpu` | cores >= `MIN_CPU` | `nproc` |
| Storage Size Is Enough | `storage` | size of each path >= `MIN_STORAGE_GB` | `df -BG --output=size` |
| Storage Is Not Too Full | `storage` | used % <= `MAX_USED_PERCENT` | `df --output=pcent` |
| Bond Exists | `bond` | `/proc/net/bonding/<bond>` exists | file check |
| Bond Configuration Is Correct | `bond` | mode matches `BOND_MODE`, NIC count = `BOND_SLAVES`, MTU = `BOND_MTU` | `grep` on `/proc/net/bonding`, `/sys/class/net/<bond>/mtu` |
| Bond Status Is Up | `bond` | bond MII status up and no NIC down | `sed`/`awk` on `/proc/net/bonding` |
| Bond LACP Partner Is Negotiated | `bond` | partner MAC is not `00:00:00:00:00:00` (only for 802.3ad) | `grep` "details partner lacp pdu" |
| Interface Exists | `interface` | `/sys/class/net/<iface>` exists for bonds + extra interfaces | directory check |
| Interface Status Is Up | `interface` | `operstate` is `up` (+ MTU if set) | `cat /sys/class/net/<iface>/operstate` |
| Internet Is Reachable | `internet` | `curl` to `INTERNET_URL` succeeds | `curl -sf -m 10` |
| DNS Names Resolve | `dns` | every name resolves | `getent hosts` or `dig +short @server` |
| NTP Is Synchronised | `ntp` | `NTPSynchronized=yes` (+ server in chrony sources if set) | `timedatectl`, `chronyc sources` |

---

## 8. Common scenarios

| Goal | What to do |
|------|-----------|
| Check only network on a server | `robot --include bond --include interface --include internet --include dns --include ntp script.robot` |
| Server has no bonds | Leave `@{BONDS}` empty; bond tests are skipped |
| Behind a proxy | Export the proxy before running: `export https_proxy=http://proxy:3128` then run `robot` (curl uses it) |
| Internal DNS server | Set `DNS_SERVER` to its IP |
| Internal NTP server | Set `NTP_SERVER` to its IP or name |
| Different thresholds per environment | Use separate env files or `-v` overrides |
| Skip storage checks | Leave `@{STORAGE_PATHS}` empty |
| Check several mount points | `@{STORAGE_PATHS}   /   /var   /data` |

---

## 9. Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `Interface bond2 not found` when you only listed bond0 and bond1 | bond2 is listed in `@{INTERFACES}` | Remove it. Bonds in `@{BONDS}` are checked automatically; `@{INTERFACES}` is only for extra interfaces |
| `Bond bondX not found` | Bond does not exist on this server | Fix the name in `@{BONDS}`, or leave it empty on servers with no bonds |
| `Resource file 'env.resource' does not exist` | Files are not in the same folder, or you run from another folder | `cd` to the folder, or use full path: `robot /path/to/script.robot` |
| `No keyword with name 'IF'` or similar syntax errors | Robot Framework older than 5.0 | `pip3 install --upgrade robotframework` |
| `bash: dig: command not found` | `DNS_SERVER` is set but `dig` is missing | Install `dnsutils` (Ubuntu) or `bind-utils` (RHEL), or leave `DNS_SERVER` empty |
| DNS test fails but internet works | System resolver cannot resolve a listed name | Check `/etc/resolv.conf` or set `DNS_SERVER` |
| NTP fails: `Clock is not synchronised` | Time sync not enabled or not yet synced | `timedatectl set-ntp true`, check `chronyc tracking` |
| `Bond LACP Partner Is Negotiated` fails | Switch port-channel/LACP not configured, or MLAG mismatch | Check the switch side; compare `/proc/net/bonding/<bond>` |
| Internet fails | No route, firewall, or proxy needed | Test `curl -v <URL>`; export the proxy variable if required |
| Values with spaces are split | Robot splits on 2+ spaces | Keep one space inside a value, use 2+ spaces between items |
| Test shows `SKIP` | The related list is empty | Intended. Add values in `env.resource` to enable it |

---

## 10. How it works internally

- **One helper keyword, `Run Ok`.** It runs a shell command with `Run And Return Rc And Output`, fails the test if the exit code is not 0, and returns the output.
- **Interface list.** The keyword `Get Interface List` joins `BONDS` and `INTERFACES` and removes duplicates, so bonds are checked as interfaces without repeating them.
- **Skipping.** Each test starts with `Skip If not $LIST`, so an empty list in the env file skips the test instead of failing it.
- **Env file.** `script.robot` imports `env.resource` with `Resource env.resource`, so settings are fully separate from the test logic. Command-line `-v NAME:value` overrides take priority over the file.
- **Read-only.** The tests only read system information and make network requests; they never change the server.

### Adding your own check

Add a new test case to `script.robot` using `Run Ok`:

```robot
Docker Is Running
    [Tags]    docker
    Run Ok    systemctl is-active --quiet docker    Docker is not running
```

Run it with `robot --include docker script.robot`.

To add a configurable value, put the variable in `env.resource` and use it in the test as `${MY_VALUE}`.
