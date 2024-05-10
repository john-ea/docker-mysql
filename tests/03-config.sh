#!/usr/bin/env bash
set -e
set -u
set -o pipefail

IMAGE="${5}/mysql"
NAME="${1}"
VERSION="${2}"
TAG="${3}"
ARCH="${4}"

CWD="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"
# shellcheck disable=SC1091
. "${CWD}/.lib.sh"


# Custom MySQL configuration
CNF_DIR="$( mktemp -d )"
chmod 0755 "${CNF_DIR}"
CNF_KEY="general_log_file"
CNF_VAL="/var/log/devilbox.log"
echo "[mysqld]" > "${CNF_DIR}/config.cnf"
echo "${CNF_KEY} = ${CNF_VAL}" >> "${CNF_DIR}/config.cnf"
DB="mysql"

if [ "${NAME}" = "mariadb" ] && [ "$(ver "${VERSION}")" -ge "$(ver "11")" ]; then
  DB="mariadb"
fi

# Start MySQL
run "docker run -d --rm --platform ${ARCH} $(tty -s && echo "-it" || echo) --hostname=mysql --name devilbox-test-mysql -e MYSQL_ALLOW_EMPTY_PASSWORD=yes -v ${CNF_DIR}:/etc/mysql/docker-default.d ${IMAGE}:${TAG}"

# Test MySQL connectivity
max=100
i=0
while ! run "docker exec $(tty -s && echo "-it" || echo) devilbox-test-mysql ${DB} -uroot --password='' -h 127.0.0.1 -e \"SHOW VARIABLES LIKE '%%${CNF_KEY}%%';\" | grep '${CNF_VAL}'"; do
	sleep 1
	i=$(( i + 1))
	if [ "${i}" -ge "${max}" ]; then
		docker logs devilbox-test-mysql  2>/dev/null || true
		docker stop devilbox-test-mysql  2>/dev/null || true
		docker kill devilbox-test-mysql  2>/dev/null || true
		docker rm -f devilbox-test-mysql 2>/dev/null || true
		rm -rf "${CNF_DIR}" || true
		>&2 echo "Failed"
		exit 1
	fi
done

run "docker stop devilbox-test-mysql"  || true
run "docker kill devilbox-test-mysql"  || true
run "docker rm -f devilbox-test-mysql" || true
rm -rf "${CNF_DIR}" || true
echo "Success"
