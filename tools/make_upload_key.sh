#!/usr/bin/env bash
# Play 업로드 키(키스토어)를 저장소 밖에 만든다. 사용자가 자기 터미널에서 직접 실행한다.
#   tools/make_upload_key.sh            → ~/.majung-keys/
#   MAJUNG_KEY_DIR=/다른/곳 tools/make_upload_key.sh
# 만들어지는 파일 (둘 다 비밀, 커밋 금지, 꼭 백업):
#   upload-keystore.jks  키 자체
#   key.properties       키 비밀번호와 위치 (Gradle 이 읽음)
set -euo pipefail

KEY_DIR="${MAJUNG_KEY_DIR:-$HOME/.majung-keys}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"

case "$(realpath -m "$KEY_DIR")/" in
  "$REPO"/*) echo "키 폴더가 저장소 안에 있으면 안 됩니다: $KEY_DIR" >&2; exit 1 ;;
esac

if [ -e "$KEY_DIR/upload-keystore.jks" ]; then
  echo "이미 키가 있습니다: $KEY_DIR/upload-keystore.jks" >&2
  echo "덮어쓰지 않습니다. 새로 만들려면 먼저 백업 후 직접 옮기세요." >&2
  exit 1
fi

read -r -s -p "키 비밀번호 (6자 이상): " PW; echo
read -r -s -p "한 번 더: " PW2; echo
[ "$PW" = "$PW2" ] || { echo "비밀번호가 다릅니다." >&2; exit 1; }
[ "${#PW}" -ge 6 ] || { echo "6자 이상이어야 합니다." >&2; exit 1; }

mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"

# 비밀번호는 명령줄 대신 환경 변수로 넘긴다 (ps 에 안 보이게)
(cd "$REPO" && MAJUNG_PW="$PW" docker compose run --rm -T \
  -v "$KEY_DIR:/keys" -e MAJUNG_PW dev \
  keytool -genkeypair -keystore /keys/upload-keystore.jks -storetype PKCS12 \
    -alias upload -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=majungdev" -storepass:env MAJUNG_PW -keypass:env MAJUNG_PW)

umask 077
cat > "$KEY_DIR/key.properties" <<PROPS
storeFile=upload-keystore.jks
storePassword=$PW
keyAlias=upload
keyPassword=$PW
PROPS
chmod 600 "$KEY_DIR/key.properties" "$KEY_DIR/upload-keystore.jks"

echo
echo "만들었습니다: $KEY_DIR"
echo "지금 이 폴더를 USB·클라우드 등 다른 곳에 백업하고, 비밀번호도 따로 적어 두세요."
echo "잃어버리면 Play 에 업로드 키 재설정을 요청해야 합니다."
