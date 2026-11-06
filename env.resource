*** Variables ***
# =====================================================================
# ENV FILE - edit only this file. Leave a list empty to skip that check.
# =====================================================================

# ---- OS ----
# Allowed OS IDs (value of ID= in /etc/os-release): ubuntu, rhel, rocky, almalinux, debian ...
@{ALLOWED_OS}          ubuntu    rhel    rocky    almalinux

# ---- CPU / RAM / STORAGE (minimums) ----
${MIN_CPU}             4
${MIN_RAM_GB}          8
@{STORAGE_PATHS}       /                      # paths (filesystems) to check
${MIN_STORAGE_GB}      50                     # minimum total size of each path
${MAX_USED_PERCENT}    85                     # fail if a path is fuller than this

# ---- BONDS ----
@{BONDS}               bond0    bond1         # empty = skip bond checks
${BOND_MODE}           802.3ad                # text shown in /proc/net/bonding (e.g. 802.3ad, active-backup)
${BOND_SLAVES}         2                      # expected NICs per bond
${BOND_MTU}            9000                   # 0 = do not check MTU

# ---- INTERFACES ----
# Bonds listed in BONDS are checked automatically (exists + status) - do NOT repeat them here.
# List only EXTRA interfaces: physical NICs, VLANs, vNICs ... e.g. eno1  eth0  enp6s18  bond0.100
@{INTERFACES}          eno12399np0            # empty = only the bonds above
${INTERFACE_MTU}       0                      # 0 = do not check MTU

# ---- INTERNET / DNS / NTP ----
${INTERNET_URL}        https://archive.ubuntu.com
@{DNS_NAMES}           google.com    archive.ubuntu.com     # names that must resolve
${DNS_SERVER}          ${EMPTY}               # empty = use the system resolver
${NTP_SERVER}          ${EMPTY}               # optional: must appear in chrony sources
