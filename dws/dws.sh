#!/bin/bash
echo "=================================================="
echo -e "\033[0;35m"
echo " :::    ::: ::::::::::: ::::    :::  ::::::::  :::::::::  :::::::::: ::::::::  ";
echo " :+:   :+:      :+:     :+:+:   :+: :+:    :+: :+:    :+: :+:       :+:    :+: ";
echo " +:+  +:+       +:+     :+:+:+  +:+ +:+    +:+ +:+    +:+ +:+       +:+        ";
echo " +#++:++        +#+     +#+ +:+ +#+ +#+    +:+ +#+    +:+ +#++:++#  +#++:++#++ ";
echo " +#+  +#+       +#+     +#+  +#+#+# +#+    +#+ +#+    +#+ +#+              +#+ ";
echo " #+#   #+#  #+# #+#     #+#   #+#+# #+#    #+# #+#    #+# #+#       #+#    #+# ";
echo " ###    ###  #####      ###    ####  ########  #########  ########## ########  ";
echo -e "\e[0m"
echo "=================================================="

sleep 2

# set vars
if [ ! $NODENAME ]; then
	read -p "Enter node name: " NODENAME
	echo 'export NODENAME='$NODENAME >> $HOME/.bash_profile
fi
echo "export WALLET=wallet" >> $HOME/.bash_profile
echo "export CHAIN_ID=deweb-testnet-1" >> $HOME/.bash_profile
source $HOME/.bash_profile

echo '================================================='
echo 'Your node name: ' $NODENAME
echo 'Your wallet name: ' $WALLET
echo 'Your chain name: ' $CHAIN_ID
echo '================================================='
sleep 2

echo -e "\e[1m\e[32m1. Updating packages... \e[0m" && sleep 1
# update
sudo apt update && sudo apt upgrade -y

echo -e "\e[1m\e[32m2. Installing dependencies... \e[0m" && sleep 1
# packages
sudo apt install curl tar wget clang pkg-config libssl-dev jq build-essential bsdmainutils git make ncdu gcc git jq chrony liblz4-tool -y

# install go
ver="1.17.2"
cd $HOME
wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
rm "go$ver.linux-amd64.tar.gz"
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> ~/.bash_profile
source ~/.bash_profile
go version

echo -e "\e[1m\e[32m3. Downloading and building binaries... \e[0m" && sleep 1
# download binary
cd $HOME
git clone https://github.com/deweb-services/deweb.git
cd deweb
git checkout v0.2
make build
sudo cp build/dewebd /usr/local/bin/dewebd

# config
dewebd config chain-id $CHAIN_ID
dewebd config keyring-backend file

# init
dewebd init $NODENAME --chain-id $CHAIN_ID

# download addrbook and genesis
wget -qO $HOME/.deweb/config/genesis.json "https://raw.githubusercontent.com/deweb-services/deweb/main/genesis.json"
wget -qO $HOME/.deweb/config/addrbook.json "https://raw.githubusercontent.com/kj89/testnet_manuals/main/dws/addrbook.json"

# set minimum gas price
sed -i -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0.001udws\"/" $HOME/.deweb/config/app.toml

# set peers and seeds
SEEDS="74d8f92c37ffe4c6393b3718ca531da8f0bf0594@seed1.deweb.services:26656"
PEERS="316d8e681019f25b078b36a26f349e48c916aace@161.97.104.113:26656,4172ea44cb18d7b8040c3c284d76340e9212fea7@95.214.53.225:26666,d2e9b0a8c0a07422c01e2477c8054ec7f2b509b6@128.199.49.193:26656,cba40403295977211209fb3b3037501e6f00f339@167.235.243.214:26656"
sed -i -e "s/^seeds *=.*/seeds = \"$SEEDS\"/; s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.deweb/config/config.toml

# enable prometheus
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.deweb/config/config.toml

# config pruning
pruning="custom"
pruning_keep_recent="100"
pruning_keep_every="0"
pruning_interval="10"

sed -i -e "s/^pruning *=.*/pruning = \"$pruning\"/" $HOME/.deweb/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$pruning_keep_recent\"/" $HOME/.deweb/config/app.toml
sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"$pruning_keep_every\"/" $HOME/.deweb/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"$pruning_interval\"/" $HOME/.deweb/config/app.toml

# reset
dewebd unsafe-reset-all

echo -e "\e[1m\e[32m4. Starting service... \e[0m" && sleep 1
# create service
tee $HOME/dewebd.service > /dev/null <<EOF
[Unit]
Description=dewebd
After=network.target
[Service]
Type=simple
User=$USER
ExecStart=$(which dewebd) start
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

sudo mv $HOME/dewebd.service /etc/systemd/system/

# start service
sudo systemctl daemon-reload
sudo systemctl enable dewebd
sudo systemctl restart dewebd

echo '=============== SETUP FINISHED ==================='
echo -e 'To check logs: \e[1m\e[32mjournalctl -u dewebd -f -o cat\e[0m'
echo -e 'To check sync status: \e[1m\e[32mcurl -s localhost:26657/status | jq .result.sync_info\e[0m'
