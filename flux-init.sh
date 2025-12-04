ROOT_DIR="clusters/home"

flux bootstrap github \
  --owner=clrosier \
  --repository=cams-lab \
  --branch=main \
  --path=$ROOT_DIR
