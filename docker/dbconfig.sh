#! /bin/bash


#  database: $DB_NAME
#  username: root
#  password: root
#  host: mysql
#  port: 3306


cat <<EOT > /app/config/database.yml
default: &default
  adapter: mysql2
  encoding: utf8
  url: mysql2://root:root@mysql:3306/$DB_NAME

development:
  <<: *default

production:
  <<: *default

test:
  <<: *default
EOT

cat <<EOT > /app/config/mongoid.yml
default: &default
  clients:
    default:
      database: wheat_expression_prd
      hosts:
        - mongo:27017
      options:
        max_pool_size: 5
        
development:
  <<: *default

production:
  <<: *default

test:
  <<: *default
EOT