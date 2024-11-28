OSS_ARG="--flavor oss"
STORE_ARG=""

dart run flutter_oss_licenses:generate

dart run remove_comment.dart

flutter pub get