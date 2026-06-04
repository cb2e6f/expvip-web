FROM almalinux:9.8
RUN dnf update -y
# ruby
ENV PATH="/root/.rbenv/bin:/root/.rbenv/shims:$PATH"
RUN dnf install git -y && \ 
  git clone https://github.com/rbenv/rbenv.git ~/.rbenv && \
  git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build && \
  dnf group install "Development Tools" -y && \
  dnf install perl -y && \
  (rbenv install 2.7.8 || cat /tmp/ruby-build.*log) && \
  rbenv global 2.7.8
# kallisto 
RUN dnf install cmake -y && \
  git clone https://github.com/pachterlab/kallisto.git && \
  cd kallisto && \
  mkdir build && \ 
  cd build && \
  cmake .. && \
  make && make install
#node
RUN curl -fsSL https://rpm.nodesource.com/setup_20.x | bash && \
  dnf install nodejs -y
# app
WORKDIR /app
COPY . .
RUN gem install bundler:1.17.3 && \
  dnf install shared-mime-info mariadb-connector-c-devel sqlite-devel -y && \
  bundle config build.nio4r "--with-cflags=-Wno-incompatible-pointer-types" && \
  bundle config build.ffi "--with-cflags=-Wno-incompatible-pointer-types" && \
  bundle config build.byebug "--with-cflags=-Wno-incompatible-pointer-types" && \
  bundle install && \
  npm install && \
  npm run bundle && \
  rbenv rehash
ADD ./docker/dbconfig.sh .
RUN chmod +x dbconfig.sh
EXPOSE 3000
ENV HOST=0.0.0.0
HEALTHCHECK --interval=5s --timeout=30s --retries=30 CMD [ "/bin/bash", "-c", "curl -f http://localhost:3000/health || exit 1"]
CMD ["/bin/bash", "-c", "/app/dbconfig.sh && npm start"]