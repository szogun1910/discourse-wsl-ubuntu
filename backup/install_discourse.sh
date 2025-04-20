bash <(wget -qO- https://raw.githubusercontent.com/discourse/install-rails/main/linux)
git clone https://github.com/discourse/discourse.git ~/discourse
cd ~/discourse
source ~/.bashrc
rbenv install 3.3.1
rbenv global 3.3.1
bundle install
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc
nvm install 20
nvm use 20
nvm alias default 20
pnpm install
bin/rails db:create
bin/rails db:migrate
RAILS_ENV=test bin/rails db:create db:migrate
bin/rails admin:create
DISCOURSE_HOSTNAME=localhost UNICORN_LISTENER=localhost:3000 ALLOW_EMBER_CLI_PROXY_BYPASS=1 bin/ember-cli -u
