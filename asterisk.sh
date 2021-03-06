#!/bin/sh

CWD=`pwd`
ME=`basename $0`
TELEGRAM_SESSION="$CWD/telegram.session"

set -e -x

trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

# 1. Build required applications

nix-build -A sox -o result-sox
export PATH=`readlink ./result-sox`/bin/:$PATH
sox --version

nix-build -A asterisk -o result-asterisk -K
nix-build -A asterisk-conf -o result-conf
nix-build -A python-scripts -o result-python
nix-build -A tg2sip -o result-tg2sip
nix-build -A tg2sip-conf -o result-tg2sip-conf
nix-build -A dongle-monitor -o result-dongle-monitor

# 2. Prepare the modem. We may need to switch it to the serial mode.

"$CWD/result-dongle-monitor/bin/dongle-monitor" &

# 3. Check Telegram session

"$CWD/result-python/bin/telegram_check.py"

# 4. Run the dongleman

"$CWD/result-python/bin/dongleman_spool.py"
"$CWD/result-python/bin/dongleman_daemon.py" &

# 4. Run TG2SIP

mkdir /tmp/tg2sip || true
cp -f "$CWD/result-tg2sip-conf/etc/settings.ini" /tmp/tg2sip/settings.ini
( cd /tmp/tg2sip && "$CWD/result-tg2sip/bin/gen_db"; )
( cd /tmp/tg2sip && "$CWD/result-tg2sip/bin/tg2sip"; ) &

# 5. Run Asterisk daemon synchronously, verbosely, interactively

sudo rm -rf /tmp/asterisk || true
sudo mkdir /tmp/asterisk

sudo "$CWD/result-asterisk/bin/asterisk" -C "$CWD/result-conf/etc/asterisk/asterisk.conf" -c -f -vvvvvvvvv

