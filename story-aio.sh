#!/bin/bash

# Define some colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

NEWCHAINID=iliad
SCRIPT_NAME="story-aio.sh"
CURRENT_VERSION="0.10.1"


function print_header {
    echo -e "\e[6;1mWelcome to KenZ|DragonVN - Story Tool AIO Install Script${NC}"
}

function manage_script {
    while true
    do
        echo "Choose an option:"
        echo "1/ Update script"
        echo "2/ Remove script"
        echo "3/ Go back to the previous menu"
        echo -n "Enter your choice [1-3]: "
        read script_option
        case $script_option in
            1) check_for_updates;;
            2) echo "Are you sure you want to remove the script? (Yes/No)"
               read remove_confirmation
               if [[ "${remove_confirmation,,}" == "yes" ]]; then
                   rm $SCRIPT_NAME
                   echo "The script has been removed."
               else
                   echo "Remove cancelled."
               fi;;
            3) return;;
            *) echo "Invalid choice. Please try again.";;
        esac
    done
}

function story_service_menu {
    while true
    do
        echo "Choose an option:"
        echo "1/ Start Story Service"
        echo "2/ Stop Story Service"
        echo "3/ Check Story Service Status"
        echo "4/ Remove all Story install (CAUTION)"
        echo "5/ Go back to the previous menu"
        echo -n "Enter your choice [1-5]: "
        read service_option
        case $service_option in
            1) echo "Starting Story Service..."
               sudo systemctl daemon-reload
               sudo systemctl enable story
               sudo systemctl start story
               echo "Story Service has been started."
               sleep 3;;
            2) echo "Stopping Story Service..."
               sudo systemctl stop story
               echo "Story Service has been stopped."
               sleep 3;;
            3) echo "Checking Story Service status..."
               clear
               sudo systemctl status story --no-pager
               echo "Press any key to continue..."
               read -n 1 -s;;
            4) echo "You have chosen 'Remove all Story install (CAUTION)'."
               echo "The system will automatically delete the current Story working directory and back it up to the following path: $HOME/story_backup/. Please be careful and make sure that you have backed up the necessary files. This action cannot be undone."
               echo "Are you sure you want to proceed? (Yes/No):"
               read confirmation
               if [[ "${confirmation,,}" == "yes" ]]; then
                   echo "Please confirm again (Yes/No):"
                   read confirmation2
                   if [[ "${confirmation2,,}" == "yes" ]]; then
                       echo "Please confirm one last time (Yes/No):"
                       read confirmation3
                       if [[ "${confirmation3,,}" == "yes" ]]; then
                           echo "Removing all Story install..."
                           cd $HOME && mkdir $HOME/story_backup
                           cp -r $HOME/.story/ $HOME/story_backup/
                           systemctl stop story && systemctl disable story
                           systemctl stop story-geth && systemctl disable story-geth
                           rm /etc/systemd/system/story* -rf
                           rm $(which story) -rf
                           rm /usr/local/bin/story* -rf
                           rm $HOME/.story* -rf
                           rm $HOME/.story -rf
                           echo "All Story installs have been removed."
                           sleep 3
                       else
                           echo "Operation cancelled."
                           sleep 3
                       fi
                   else
                       echo "Operation cancelled."
                       sleep 3
                   fi
               else
                   echo "Operation cancelled."
                   sleep 3
               fi;;
            5) echo "Going back to the previous menu..."
               return;;
            *) echo "Invalid choice. Please try again."
               sleep 3;;
        esac
    done
}

function install_story_node {
    echo "You have chosen 'Install Story Node'."
    echo "Please choose your operating system:"
    echo "1/ Linux"
    echo -n "Enter your choice [1]: "
    read os_option
    case $os_option in
        1) OPERATING_SYSTEM="linux"; OPERATING_SYSTEM_CAP="Linux";;
        *) echo "Invalid choice. Please try again."
            sleep 3
            return;;
    esac
    ARCHITECTURE="x86_64"

    # install Update
    echo "Updating and upgrading the system..."
    sudo apt update -y && sudo apt-get update -y
    sudo apt install curl git make jq build-essential gcc unzip wget lz4 aria2 -y

    # install story-geth v0.9.3
    echo "Downloading and installing story-geth..."
    wget https://story-geth-binaries.s3.us-west-1.amazonaws.com/geth-public/geth-linux-amd64-0.9.3-b224fdf.tar.gz
    tar -xzvf geth-linux-amd64-0.9.3-b224fdf.tar.gz
    [ ! -d "$HOME/go/bin" ] && mkdir -p $HOME/go/bin
    if ! grep -q "$HOME/go/bin" $HOME/.bash_profile; then echo "export PATH=$PATH:/usr/local/go/bin:~/go/bin" >> ~/.bash_profile; fi
    sudo cp geth-linux-amd64-0.9.3-b224fdf/geth $HOME/go/bin/story-geth
    source $HOME/.bash_profile
    story-geth version

    # install story v0.10.1
    echo "Downloading and installing story..."
    wget https://story-geth-binaries.s3.us-west-1.amazonaws.com/story-public/story-linux-amd64-0.10.1-57567e5.tar.gz
    tar -xzvf story-linux-amd64-0.10.1-57567e5.tar.gz
    [ ! -d "$HOME/go/bin" ] && mkdir -p $HOME/go/bin
    if ! grep -q "$HOME/go/bin" $HOME/.bash_profile; then echo "export PATH=$PATH:/usr/local/go/bin:~/go/bin" >> ~/.bash_profile; fi
    cp $HOME/story-linux-amd64-0.10.1-57567e5/story $HOME/go/bin
    source $HOME/.bash_profile
    story version

    # moniker init
    echo "Enter your moniker name:"
    read moniker
    story init --network iliad --moniker "$moniker"

    # service make
    echo "Creating and starting the story-geth and story services..."
    sudo tee /etc/systemd/system/story-geth.service > /dev/null <<EOF
[Unit]
Description=Story Geth Client
After=network.target

[Service]
User =root
ExecStart=/root/go/bin/story-geth --iliad --syncmode full
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF
    sudo tee /etc/systemd/system/story.service > /dev/null <<EOF
[Unit]
Description=Story Consensus Client
After=network.target

[Service]
User =root
ExecStart=/root/go/bin/story run
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload && sudo systemctl start story-geth && sudo systemctl enable story-geth
    sudo systemctl daemon-reload && sudo systemctl start story && sudo systemctl enable story

    # Check block
    echo "Checking the block height..."
    while true; do
        local_height=$(curl -s localhost:26657/status | jq -r '.result.sync_info.latest_block_height')
        network_height=$(curl -s https://story-rpc-testnet.kzvn.xyz//status | jq -r '.result.sync_info.latest_block_height')
        blocks_left=$((network_height - local_height))
        echo -e "\033[1;38mYour node height:\033[0m \033[1;34m$local_height\033[0m | \033[1;35mNetwork height:\033[0m \033[1;36m$network_height\033[0m | \033[1;29mBlocks left:\033[0m \033[1;31m$blocks_left\033[0m"
        sleep 5
    done
}

function story_tool_menu {
    while true
    do
        echo "Choose an option:"
        echo "1/ Check Story Status"
        echo "2/ Update Story"
        echo "3/ Update new Peers"
        echo "4/ Turn on Prometheus"
        echo "5/ Open RPC to Public"
        echo "6/ Go back to the previous menu"
        echo -n "Enter your choice [1-6]: "
        read tool_option
        case $tool_option in
            1) check_story_status;;
            2) update_story;;
            3) update_new_peer;;
            4) echo "This feature is currently under development.";;
            5) echo "This feature is currently under development.";;
            6) return;;
            *) echo "Invalid choice. Please try again.";;
        esac
    done
}

function check_story_status {
    rpc_port=$(grep -oP '(?<=laddr = "tcp://127.0.0.1:)[0-9]+' ~/.story/story/config/config.toml)
    if [ -z "$rpc_port" ]; then
        echo "\033[1;31mError: Unable to find RPC port.\033[0m"
        return
    fi

    while true; do
        local_height=$(curl -s "http://localhost:$rpc_port/status" | jq -r '.result.sync_info.latest_block_height')
        network_height=$(curl -s "https://story-rpc-testnet.kzvn.xyz//status" | jq -r '.result.sync_info.latest_block_height')

        if [ -z "$local_height" ] || [ -z "$network_height" ]; then
            echo "\033[1;31mError: Invalid block height data. Retrying...\033[0m"
            sleep 5
            continue
        fi

        blocks_left=$((network_height - local_height))
        sync_time_left=$((blocks_left * 5))  # Assuming 5 seconds per block

        echo -e "\033[1;33mYour Node Height:\033[1;34m $local_height\033[0m "
        echo -e "\033[1;33m| Network Height:\033[1;36m $network_height\033[0m "
        echo -e "\033[1;33m| Blocks Left:\033[1;31m $blocks_left\033[0m "
        echo -e "\033[1;33m| Estimated Time Left:\033[1;32m $(date -d @"$sync_time_left" -u +%H:%M:%S)\033[0m"

        sleep 5
    done
}

function update_story {
    echo "Enter the version (e.g., v0.10.1):"
    read version
    if [ -z "$version" ]; then
        version="v0.10.1"
        echo "Note: v0.10.1 is the latest version."
    fi

    commands=(
        "cd $HOME"
        "rm -rf story"
        "git clone https://github.com/piplabs/story"
        "cd $HOME/story"
        "git checkout $version"
        "go build -o story ./client"
        "sudo mv $HOME/story/story $(which story)"
        "sudo systemctl restart story && sudo journalctl -u story -f"
    )

    for command in "${commands[@]}"; do
        echo "Executing command: $command"
        eval "$command"
    done
}

function security_story_menu {
    echo "This feature is currently under development."
    while true
    do
        echo "Choose an option:"
        echo "1/ Turn On/Off Port 26657"
        echo "2/ Go back to the previous menu"
        echo -n "Enter your choice [1-2]: "
        read security_option
        case $security_option in
            1) echo "This feature is currently under development.";;
            2) return;;
            *) echo "Invalid choice. Please try again.";;
        esac
    done
}

function update_new_peer {
    PEERS=$(curl -s -X POST https://story-rpc-testnet.kzvn.xyz -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"net_info","params":[],"id":1}' | jq -r '.result.peers[] | select(.connection_status.SendMonitor.Active == true) | "\(.node_info.id)@\(if .node_info.listen_addr | contains("0.0.0.0") then .remote_ip + ":" + (.node_info.listen_addr | sub("tcp://0.0.0.0:"; "")) else .node_info.listen_addr | sub("tcp://"; "") end)"' | tr '\n' ',' | sed 's/,$//' | awk '{print "\"" $0 "\""}')
    sed -i "s/^persistent_peers *=.*/persistent_peers = $PEERS/" "$HOME/.story/story/config/config.toml"
    if [ $? -eq 0 ]; then
        echo -e "Configuration file updated successfully with new peers"
    else
        echo "Failed to update configuration file."
    fi

    echo -e "restart story service"
    systemctl restart story && journalctl -u story -f -o cat
}


function main_menu {
    while true
    do
        clear
        print_header

        # menuList

        echo "Please choose an option:"
        echo "1/ Install Story - All in One Script"
        echo "2/ Start/Stop/Check/Remove Story Service"
        echo "3/ Story Tool (UD)"
        echo "4/ Security Story node/validator (UD)"
        echo "5/ Exit"
        echo -n "Enter your choice [1-5]: "

        read option
        case $option in
            1) install_story_node;;
            2) story_service_menu;;
            3) story_tool_menu;;
            4) security_story_menu;;
            5) echo "You have chosen 'Exit'."
               exit 0;;
            *) echo "Invalid choice. Please try again."
               sleep 3;;
        esac
    done
}

main_menu
