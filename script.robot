*** Settings ***
Documentation     Generic server pre-check: OS, RAM, CPU, storage, bond, interface, internet, DNS, NTP.
...               All settings are in env.resource.   Run:  robot precheck.robot
...               Single area:  robot --include bond precheck.robot
Library           OperatingSystem
Library           String
Library           Collections
Resource          env.resource

*** Test Cases ***
# ======================= SYSTEM =======================
OS Type Is Allowed
    [Tags]    os
    Skip If    not $ALLOWED_OS
    ${kernel}=    Run Ok    uname -s
    Should Be Equal    ${kernel}    Linux
    ${id}=    Run Ok    . /etc/os-release && echo $ID
    ${ver}=    Run Ok    . /etc/os-release && echo $PRETTY_NAME
    Log    Detected OS: ${ver}    console=yes
    Should Contain    ${ALLOWED_OS}    ${id}    OS '${id}' is not in allowed list ${ALLOWED_OS}

RAM Is Enough
    [Tags]    ram
    ${gb}=    Run Ok    awk '/MemTotal/{printf "%d",$2/1024/1024+0.5}' /proc/meminfo
    Log    RAM: ${gb} GB    console=yes
    Should Be True    ${gb} >= ${MIN_RAM_GB}    RAM is ${gb} GB, need ${MIN_RAM_GB} GB

CPU Is Enough
    [Tags]    cpu
    ${n}=    Run Ok    nproc
    Log    CPU cores: ${n}    console=yes
    Should Be True    ${n} >= ${MIN_CPU}    CPU is ${n}, need ${MIN_CPU}

Storage Size Is Enough
    [Tags]    storage
    Skip If    not $STORAGE_PATHS
    FOR    ${p}    IN    @{STORAGE_PATHS}
        ${gb}=    Run Ok    df -BG --output=size ${p} | tail -1 | tr -dc 0-9
        Log    ${p}: ${gb} GB    console=yes
        Should Be True    ${gb} >= ${MIN_STORAGE_GB}    ${p} is ${gb} GB, need ${MIN_STORAGE_GB} GB
    END

Storage Is Not Too Full
    [Tags]    storage
    Skip If    not $STORAGE_PATHS
    FOR    ${p}    IN    @{STORAGE_PATHS}
        ${used}=    Run Ok    df --output=pcent ${p} | tail -1 | tr -dc 0-9
        Should Be True    ${used} <= ${MAX_USED_PERCENT}    ${p} is ${used}% used (max ${MAX_USED_PERCENT}%)
    END

# ======================= BOND =======================
Bond Exists
    [Tags]    bond
    Skip If    not $BONDS
    FOR    ${b}    IN    @{BONDS}
        File Should Exist    /proc/net/bonding/${b}    Bond ${b} not found
    END

Bond Configuration Is Correct
    [Tags]    bond
    Skip If    not $BONDS
    FOR    ${b}    IN    @{BONDS}
        Run Ok    grep -q "Bonding Mode:.*${BOND_MODE}" /proc/net/bonding/${b}    ${b} mode is not ${BOND_MODE}
        ${n}=    Run Ok    grep -c "^Slave Interface" /proc/net/bonding/${b}
        Should Be Equal As Integers    ${n}    ${BOND_SLAVES}    ${b} has ${n} NICs, expected ${BOND_SLAVES}
        IF    ${BOND_MTU} > 0
            ${m}=    Run Ok    cat /sys/class/net/${b}/mtu
            Should Be Equal As Integers    ${m}    ${BOND_MTU}    ${b} MTU is ${m}, expected ${BOND_MTU}
        END
    END

Bond Status Is Up
    [Tags]    bond
    Skip If    not $BONDS
    FOR    ${b}    IN    @{BONDS}
        Run Ok    sed -n '1,/^Slave Interface/p' /proc/net/bonding/${b} | grep "MII Status" | grep -q up    ${b} itself is down
        ${down}=    Run Ok    awk '/^Slave Interface/{s=$3} /^MII Status/&&s&&$3!="up"{print s}' /proc/net/bonding/${b}
        Should Be Empty    ${down}    ${b}: NIC(s) down: ${down}
    END

Bond LACP Partner Is Negotiated
    [Tags]    bond
    Skip If    not $BONDS or '${BOND_MODE}' != '802.3ad'    Only for 802.3ad
    FOR    ${b}    IN    @{BONDS}
        File Should Exist    /proc/net/bonding/${b}    Bond ${b} not found
        Run Ok    ! grep -A8 "details partner lacp pdu" /proc/net/bonding/${b} | grep -q "system mac address: 00:00:00:00:00:00"    ${b}: switch side LACP not negotiated
    END

# ======================= INTERFACE =======================
Interface Exists
    [Tags]    interface
    ${all}=    Get Interface List
    Skip If    not $all
    FOR    ${i}    IN    @{all}
        Directory Should Exist    /sys/class/net/${i}    Interface ${i} not found
    END

Interface Status Is Up
    [Tags]    interface
    ${all}=    Get Interface List
    Skip If    not $all
    FOR    ${i}    IN    @{all}
        Directory Should Exist    /sys/class/net/${i}    Interface ${i} not found
        ${state}=    Run Ok    cat /sys/class/net/${i}/operstate
        Should Be Equal    ${state}    up    ${i} state is ${state}
        IF    ${INTERFACE_MTU} > 0
            ${m}=    Run Ok    cat /sys/class/net/${i}/mtu
            Should Be Equal As Integers    ${m}    ${INTERFACE_MTU}    ${i} MTU is ${m}
        END
    END

# ======================= NETWORK SERVICES =======================
Internet Is Reachable
    [Tags]    internet
    Run Ok    curl -sf -m 10 -o /dev/null ${INTERNET_URL}    Cannot reach ${INTERNET_URL} (check gateway/proxy/firewall)

DNS Names Resolve
    [Tags]    dns
    Skip If    not $DNS_NAMES
    FOR    ${name}    IN    @{DNS_NAMES}
        IF    '${DNS_SERVER}' == ''
            Run Ok    getent hosts ${name}    ${name} does not resolve
        ELSE
            Run Ok    dig +short +time=3 +tries=1 @${DNS_SERVER} ${name} | grep -q .    ${name} not resolved by ${DNS_SERVER}
        END
    END

NTP Is Synchronised
    [Tags]    ntp
    ${sync}=    Run Ok    timedatectl show -p NTPSynchronized --value    Cannot read time status
    Should Be Equal    ${sync}    yes    Clock is not synchronised
    IF    '${NTP_SERVER}' != ''
        Run Ok    chronyc sources | grep -q "${NTP_SERVER}"    ${NTP_SERVER} is not a chrony source
    END

*** Keywords ***
Get Interface List
    [Documentation]    Interfaces to check = every bond in BONDS + extra ones in INTERFACES (no duplicates).
    ${all}=    Combine Lists    ${BONDS}    ${INTERFACES}
    ${all}=    Remove Duplicates    ${all}
    RETURN    ${all}

Run Ok
    [Documentation]    Run a shell command; fail if exit code is not 0; return output.
    [Arguments]    ${cmd}    ${msg}=Command failed
    ${rc}    ${out}=    Run And Return Rc And Output    ${cmd}
    Should Be Equal As Integers    ${rc}    0    ${msg}\nCommand: ${cmd}\nOutput: ${out}
    ${out}=    Strip String    ${out}
    RETURN    ${out}
