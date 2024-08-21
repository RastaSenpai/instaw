#!/bin/bash
#
# functions for setting up app backend
#######################################
# creates REDIS db using docker
# Arguments:
#   None
#######################################
backend_redis_create() {
  print_banner
  printf "${WHITE} 💻 Criando Redis & Banco Postgres...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  # Adicionando o usuário ao grupo docker e criando Redis
  usermod -aG docker deploy
  docker run --name redis-${instancia_add} -p ${redis_port}:6379 --restart always --detach redis redis-server --requirepass ${mysql_root_password}
  
  sleep 2

  # Criando o banco de dados e usuário Postgres
  su - postgres <<EOF
  createdb ${instancia_add};
  psql <<SQL
  CREATE USER ${instancia_add} SUPERUSER INHERIT CREATEDB CREATEROLE;
  ALTER USER ${instancia_add} PASSWORD '${mysql_root_password}';
SQL
EOF

  sleep 2
}

#######################################
# sets environment variable for backend.
# Arguments:
#   None
#######################################
backend_set_env() {
  print_banner
  printf "${WHITE} 💻 Configurando variáveis de ambiente (backend)...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  # ensure idempotency
  backend_url=$(echo "${backend_url/https:\/\/}")
  backend_url=${backend_url%%/*}
  backend_url=https://$backend_url

  # ensure idempotency
  frontend_url=$(echo "${frontend_url/https:\/\/}")
  frontend_url=${frontend_url%%/*}
  frontend_url=https://$frontend_url

  # Configurando as variáveis de ambiente
  cat <<[-]EOF > /home/deploy/${instancia_add}/backend/.env
NODE_ENV=
BACKEND_URL=${backend_url}
FRONTEND_URL=${frontend_url}
PROXY_PORT=443
PORT=${backend_port}

DB_DIALECT=postgres
DB_HOST=localhost
DB_PORT=5432
DB_USER=${instancia_add}
DB_PASS=${mysql_root_password}
DB_NAME=${instancia_add}

JWT_SECRET=${jwt_secret}
JWT_REFRESH_SECRET=${jwt_refresh_secret}

REDIS_URI=redis://:${mysql_root_password}@127.0.0.1:${redis_port}
REDIS_OPT_LIMITER_MAX=1
REGIS_OPT_LIMITER_DURATION=3000

USER_LIMIT=${max_user}
CONNECTIONS_LIMIT=${max_whats}
CLOSED_SEND_BY_ME=true

MAIL_HOST="smtp.hostinger.com"
MAIL_USER="contato@seusite.com"
MAIL_PASS="senha"
MAIL_FROM="Recuperar Senha <contato@seusite.com>"
MAIL_PORT="465"

[-]EOF

  sleep 2
}

#######################################
# installs node.js dependencies
# Arguments:
#   None
#######################################
backend_node_dependencies() {
  print_banner
  printf "${WHITE} 💻 Instalando dependências do backend...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  # Instalando dependências do backend
  su - deploy -c "
  cd /home/deploy/${instancia_add}/backend
  npm install
  "

  sleep 2
}

#######################################
# compiles backend code
# Arguments:
#   None
#######################################
backend_node_build() {
  print_banner
  printf "${WHITE} 💻 Compilando o código do backend...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  # Compilando o backend
  su - deploy -c "
  cd /home/deploy/${instancia_add}/backend
  npm run build
  "

  sleep 2
}

#######################################
# updates backend code
# Arguments:
#   None
#######################################
backend_update() {
  print_banner
  printf "${WHITE} 💻 Atualizando o backend...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  # Atualizando o backend
  su - deploy -c "
  cd /home/deploy/${empresa_atualizar}
  pm2 stop ${empresa_atualizar}-backend
  git pull
  cd /home/deploy/${empresa_atualizar}/backend
  npm install
  npm update -f
  npm install @types/fs-extra
  rm -rf dist 
  npm run build
  npx sequelize db:migrate
  npx sequelize db:seed
  pm2 start ${empresa_atualizar}-backend
  pm2 save 
  "

  sleep 2
}

#######################################
# runs db migrate
# Arguments:
#   None
#######################################
backend_db_migrate() {
  print_banner
  printf "${WHITE} 💻 Executando db:migrate...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  # Executando migrações
  su - deploy -c "
  cd /home/deploy/${instancia_add}/backend
  npx sequelize db:migrate
  "

  sleep 2
}

#######################################
# runs db seed
# Arguments:
#   None
#######################################
backend_db_seed() {
  print_banner
  printf "${WHITE} 💻 Executando db:seed...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  # Executando seed
  su - deploy -c "
  cd /home/deploy/${instancia_add}/backend
  npx sequelize db:seed:all
  "

  sleep 2
}

#######################################
# starts backend using pm2 in 
# production mode.
# Arguments:
#   None
#######################################
backend_start_pm2() {
  print_banner
  printf "${WHITE} 💻 Iniciando pm2 (backend)...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  # Iniciando backend com pm2
  su - deploy -c "
  cd /home/deploy/${instancia_add}/backend
  pm2 start dist/server.js --name ${instancia_add}-backend
  "

  sleep 2
}

#######################################
# updates frontend code
# Arguments:
#   None
#######################################
backend_nginx_setup() {
  print_banner
  printf "${WHITE} 💻 Configurando nginx (backend)...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  backend_hostname=$(echo "${backend_url/https:\/\/}")

  # Configurando nginx
  cat > /etc/nginx/sites-available/${instancia_add}-backend << END
server {
  server_name $backend_hostname;
  location / {
    proxy_pass http://127.0.0.1:${backend_port};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_cache_bypass \$http_upgrade;
  }
}
END
  ln -s /etc/nginx/sites-available/${instancia_add}-backend /etc/nginx/sites-enabled

  sleep 2
}

