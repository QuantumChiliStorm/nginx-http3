set -e

# Set up working directory
cd /github/home

echo "Install dependencies."
# Install necessary packages for building Nginx on AlmaLinux
dnf install -y epel-release 
dnf install -y elrepo-release
dnf install -y --nogpgcheck https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E %rhel).noarch.rpm
dnf install -y --nogpgcheck https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-$(rpm -E %rhel).noarch.rpm https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-$(rpm -E %rhel).noarch.rpm
dnf groupinstall -y "Development Tools" 
dnf install -y cmake git libmaxminddb wget rpm-build pcre-devel brotli-devel pcre2-devel rpmdevtools openssl-devel perl
wget https://nginx.org/download/nginx-1.27.1.tar.gz
tar -xf nginx-1.27.1.tar.gz
cd nginx-1.27.1
mkdir almalinux
mkdir almalinux/modules
cd almalinux/modules
git clone --depth 1 --recursive https://github.com/quictls/openssl
git clone --depth 1 --recursive https://github.com/google/ngx_brotli
mkdir ngx_brotli/deps/brotli/out
cd ngx_brotli/deps/brotli/out
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX=installed ..
cmake --build . --config Release --target brotlienc
cd ../../../..
git clone --depth 1 --recursive https://github.com/leev/ngx_http_geoip2_module
git clone --depth 1 --recursive https://github.com/openresty/headers-more-nginx-module
cd /github/home/nginx-1.27.1

./configure --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp  --add-module=./almalinux/modules/ngx_brotli  --add-module=./almalinux/modules/headers-more-nginx-module --user=nginx --group=nginx --with-compat --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_ssl_module --with-mail --with-mail_ssl_module --with-file-aio --with-threads --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module --with-pcre-jit --with-http_v2_module --with-openssl=./almalinux/modules/openssl



# Load previous hash, patch, and minor versions
patch=$(cat /github/workspace/patch)
minor=$(cat /github/workspace/minor)

if [[ $hash != $(cat /github/workspace/hash) ]]; then
  echo $hash > /github/workspace/hash
  if [[ $GITHUB_EVENT_NAME == push ]]; then
    patch=0
    minor=$(($(cat /github/workspace/minor)+1))
    echo $minor > /github/workspace/minor
  else
    patch=$(($(cat /github/workspace/patch)+1))
  fi
  echo $patch > /github/workspace/patch
  change=1
  echo "This is a new version."
else
  echo "This is an old version."
fi

# Save environment variables
echo -e "hash=$hash\npatch=$patch\nminor=$minor\nchange=$change" >> $GITHUB_ENV

