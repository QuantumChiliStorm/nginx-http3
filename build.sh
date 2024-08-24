set -e

# Set up working directory
cd /github/home

echo "Install dependencies."
# Install necessary packages for building Nginx on AlmaLinux
dnf install -y epel-release > /dev/null 2>&1
dnf groupinstall -y "Development Tools" > /dev/null 2>&1
dnf install -y cmake git libmaxminddb-devel wget rpm-build > /dev/null 2>&1

echo "Fetch NGINX source code."
# Download Nginx source RPM and extract it
wget -qO- https://nginx.org/packages/mainline/centos/9/SRPMS/nginx-1.27.1-1.el9.ngx.src.rpm | rpm2cpio | cpio -idmv > /dev/null 2>&1

# Extract the nginx spec file
rpmdev-setuptree
mv nginx.spec ~/rpmbuild/SPECS/
cp nginx-*.tar.gz ~/rpmbuild/SOURCES/

echo "Fetch quictls source code."
# Clone and set up additional modules
mkdir -p ~/rpmbuild/SOURCES/modules
cd ~/rpmbuild/SOURCES/modules

git clone --depth 1 --recursive https://github.com/quictls/openssl > /dev/null 2>&1

echo "Fetch additional dependencies."
git clone --depth 1 --recursive https://github.com/google/ngx_brotli > /dev/null 2>&1
mkdir ngx_brotli/deps/brotli/out
cd ngx_brotli/deps/brotli/out
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX=installed .. > /dev/null 2>&1
cmake --build . --config Release --target brotlienc > /dev/null 2>&1

cd ~/rpmbuild/SOURCES/modules
git clone --depth 1 --recursive https://github.com/leev/ngx_http_geoip2_module > /dev/null 2>&1
git clone --depth 1 --recursive https://github.com/openresty/headers-more-nginx-module > /dev/null 2>&1

echo "Prepare Nginx for building."
cd ~/rpmbuild/SPECS/

# Modify the spec file to include custom modules and options
sed -i 's|%define _with_compat 1|%define _with_compat 0|g' nginx.spec
sed -i 's|%define _with_stream 1|%define _with_stream 0|g' nginx.spec
sed -i 's|--with-compat||g' nginx.spec
sed -i 's|--with-http_ssl_module|--with-http_ssl_module --add-module=~/rpmbuild/SOURCES/modules/ngx_brotli --add-module=~/rpmbuild/SOURCES/modules/ngx_http_geoip2_module --add-module=~/rpmbuild/SOURCES/modules/headers-more-nginx-module|g' nginx.spec
sed -i 's|--with-stream_ssl_preread_module|--with-pcre-jit --with-openssl=~/rpmbuild/SOURCES/modules/openssl|g' nginx.spec

echo "Build Nginx RPM package."
# Build the RPM package
rpmbuild -ba nginx.spec > /dev/null 2>&1

echo "Package Nginx."
# Copy the built RPM package to the desired location
cp ~/rpmbuild/RPMS/x86_64/nginx-*.rpm nginx.rpm

# Calculate hash of the built RPM
hash=$(sha256sum nginx.rpm | awk '{print $1}')

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

