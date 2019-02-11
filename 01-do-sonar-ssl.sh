#! /bin/bash
source config.sh
set -o pipefail

mkdir -p "$STORAGE_FOLDER"
mkdir -p "$RESULT_FOLDER"

COPT="-s -H 'X-Api-Key: $API_KEY'"
API="https://us.api.insight.rapid7.com/opendata/studies"

function get_simple_study() {
  STUDY="$1"
  2>&1 echo "[INFO] Looking through study $STUDY"
  curl -s -H "X-Api-Key: $API_KEY" "$API/" | \
  jq -r ".[] | select(.uniqid == \"$STUDY\") | .sonarfile_set[] | select(contains(\"_names\"))" | \
  cat| \
  grep -v -P '^20(13|14|15|16|17|18)|^201901' |\
  while read -r SONARFILE;
    do
      FPF="$(curl -s -H "X-Api-Key: $API_KEY" "$API/$STUDY/$SONARFILE/" | jq -r .fingerprint | tr -dc '[:alnum:]')";
      #FPF="$(echo "718e5b8afb83f3ed21eb14326f9d71fc6a87602a/20190111" | tr -dc '[:alnum:]')"
      #FPF="$(echo "$FP" | tr -dc '[:alnum:]' )"
      if [ -f "$RESULT_FOLDER/$FPF" ]; then
        2>&1 echo "[INFO] Found $RESULT_FOLDER/$FPF, skipping ($SONARFILE)"
        continue;
      else
        2>&1 echo "[INFO] Didn't find $RESULT_FOLDER/$FPF, starting processing ($SONARFILE)"
        if [ ! -f "$STORAGE_FOLDER/$FPF" ]; then
          2>&1 echo "[INFO] Didn't find $STORAGE_FOLDER/$FPF, getting download link ($SONARFILE)"
          DL="$(curl -s -H "X-Api-Key: $API_KEY" "$API/$STUDY/$SONARFILE/download/")"
          #DL='{"url":"https://<someurl>"}'
          #DL='{"desc":"you've been throttled"}'
          URL="$(echo $DL | jq -r .url)";
          if [ "$URL" == "null" ]; then
            2>&1 echo "[INFO] We did not get a URL when expected, we are probaly throttled. Gracefully quitting. ($DL)"
            exit 0;
          fi
          2>&1 echo "[INFO] Downloading $STORAGE_FOLDER/$FPF using $URL ($SONARFILE)"
          wget -q -O "$STORAGE_FOLDER/$FPF" "$URL";
        else
          2>&1 echo "[INFO] Found $STORAGE_FOLDER/$FPF, not downloading again ($SONARFILE)"
        fi
        zcat "$STORAGE_FOLDER/$FPF" | grep -F '.no' | "$MCN_TOOLS/default_extract" > "$RESULT_FOLDER/$FPF.tmp"
        mv "$RESULT_FOLDER/$FPF.tmp" "$RESULT_FOLDER/$FPF"
        rm "$STORAGE_FOLDER/$FPF" 
      fi
    done;
}

get_simple_study "sonar.ssl"
get_simple_study "sonar.moressl"
