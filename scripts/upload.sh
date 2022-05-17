#!/bin/bash

# add ssh public keys to ssh known hosts
mkdir -p ~/.ssh
ssh-keyscan -H "${SFTP_HOST}" >> ~/.ssh/known_hosts

# upload file using rsync, if the file exists it will not be overwritten
upload-file_x86-64() {
  SSHPASS="${SFTP_PASSWORD}" sshpass -e rsync -avL --ignore-existing ${@} -e ssh "${SFTP_USER}@${SFTP_HOST}:${SFTP_CWD}/x86_64"
}

upload-file_x86-64-v3() {
  SSHPASS="${SFTP_PASSWORD}" sshpass -e rsync -avL --ignore-existing ${@} -e ssh "${SFTP_USER}@${SFTP_HOST}:${SFTP_CWD}/x86_64-v3"
}

for file in ./packages-x86-64/*.pkg.tar*
do
  if [ -f "${file}" ]
  then
    echo "::group::[i] Upload file '$(basename $file)'"

    for (( i=0; i<25; i++ ))
    do
      upload-file_x86-64 ${file}

      EXIT_STATUS=$?
      echo "[i] exit code: $EXIT_STATUS"

      if ! (( $EXIT_STATUS ))
      then
        break
      else
        sleep $(( 5 * (i + 1)))
      fi
    done

    EXIT_CODE=$?

    if (( $EXIT_CODE ))
    then
      echo "failed to upload file '$(basename $file)'!"

      FAIL_UPLOAD+="$(basename $file)"
    fi

    echo "::endgroup::"
  fi
done

for file in ./packages-x86-64-v3/*.pkg.tar*
do
  if [ -f "${file}" ]
  then
    echo "::group::[i] Upload file '$(basename $file)'"

    for (( i=0; i<25; i++ ))
    do
      upload-file_x86-64-v3 ${file}

      EXIT_STATUS=$?
      echo "[i] exit code: $EXIT_STATUS"

      if ! (( $EXIT_STATUS ))
      then
        break
      else
        sleep $(( 5 * (i + 1)))
      fi
    done

    EXIT_CODE=$?

    if (( $EXIT_CODE ))
    then
      echo "failed to upload file '$(basename $file)'!"

      FAIL_UPLOAD+="$(basename $file)"
    fi

    echo "::endgroup::"
  fi
done
