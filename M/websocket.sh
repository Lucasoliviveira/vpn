#!/bin/bash

# Função para exibir a barra de progresso
fun_bar() {
    comando[0]="$1"
    comando[1]="$2"
    (
        [[ -e $HOME/fim ]] && rm $HOME/fim
        ${comando[0]} > /dev/null 2>&1
        ${comando[1]} > /dev/null 2>&1
        touch $HOME/fim
    ) > /dev/null 2>&1 &
    tput civis
    echo -e "\033[1;31m---------------------------------------------------\033[1;37m"
    echo -ne "${col7}    AGUARDE..\033[1;35m["
    while true; do
        for ((i=0; i<18; i++)); do
            echo -ne "\033[1;34m#"
            sleep 0.2s
        done
        [[ -e $HOME/fim ]] && rm $HOME/fim && break
        echo -e "${col5}"
        sleep 1s
        tput cuu1
        tput dl1
        echo -ne "\033[1;37m    AGUARDE..\033[1;35m["
    done
    echo -e "\033[1;35m]\033[1;37m -\033[1;32m INSTALADO !\033[1;37m"
    tput cnorm
    echo -e "\033[1;31m---------------------------------------------------\033[1;37m"
}

# Função para instalação do SSL
inst_ssl() {
    echo "Instalando SSL..."
    apt-get install stunnel4 -y || { echo "Erro ao instalar stunnel4"; exit 1; }
    echo -e "client = no\n[SSL]\ncert = /etc/stunnel/stunnel.pem\naccept = 443 \nconnect = 127.0.0.1:80" > /etc/stunnel/stunnel.conf
    openssl genrsa -out stunnel.key 2048 > /dev/null 2>&1 || { echo "Erro ao gerar chave SSL"; exit 1; }
    (echo "" ; echo "" ; echo "" ; echo "" ; echo "" ; echo "" ; echo "@cloudflare") | openssl req -new -key stunnel.key -x509 -days 1000 -out stunnel.crt || { echo "Erro ao gerar certificado SSL"; exit 1; }
    cat stunnel.crt stunnel.key > stunnel.pem
    mv stunnel.pem /etc/stunnel/ || { echo "Erro ao mover certificado"; exit 1; }
    sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
    service stunnel4 restart || { echo "Erro ao reiniciar serviço stunnel"; exit 1; }
    rm -rf /etc/ger-frm/stunnel.crt /etc/ger-frm/stunnel.key /root/stunnel.crt /root/stunnel.key
}

# Função para instalação e configuração do Python
inst_py() {
    echo "Instalando Python e configurando proxy..."
    pkill -f 80
    pkill python
    apt install python -y || { echo "Erro ao instalar Python"; exit 1; }
    apt install screen -y || { echo "Erro ao instalar screen"; exit 1; }

    pt=$(netstat -nplt | grep 'sshd' | awk -F ":" 'NR==1 {print $2}' | cut -d " " -f 1)

    cat <<EOF > proxy.py
import socket, threading, select, time, sys

# Configurações
LISTENING_ADDR = '0.0.0.0'
LISTENING_PORT = 1080
PASS = ''

# Constantes
BUFLEN = 4096 * 4
TIMEOUT = 60
DEFAULT_HOST = "127.0.0.1:$pt"
RESPONSE = 'HTTP/1.1 101 $msgbanner \r\n\r\n'

class Server(threading.Thread):
    def __init__(self, host, port):
        threading.Thread.__init__(self)
        self.running = False
        self.host = host
        self.port = port
        self.threads = []
        self.threadsLock = threading.Lock()

    def run(self):
        self.soc = socket.socket(socket.AF_INET)
        self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.soc.settimeout(2)
        self.soc.bind((self.host, self.port))
        self.soc.listen(0)
        self.running = True

        try:
            while self.running:
                c, addr = self.soc.accept()
                c.setblocking(1)
                conn = ConnectionHandler(c, self, addr)
                conn.start()
                self.addConn(conn)
        finally:
            self.running = False
            self.soc.close()

    def addConn(self, conn):
        try:
            self.threadsLock.acquire()
            if self.running:
                self.threads.append(conn)
        finally:
            self.threadsLock.release()

class ConnectionHandler(threading.Thread):
    def __init__(self, socClient, server, addr):
        threading.Thread.__init__(self)
        self.client = socClient
        self.server = server

    def run(self):
        self.client.recv(BUFLEN)
        self.server.printLog(self.log)

    def close(self):
        self.client.shutdown(socket.SHUT_RDWR)
        self.client.close()
        self.target.shutdown(socket.SHUT_RDWR)
        self.target.close()

def main():
    server = Server(LISTENING_ADDR, LISTENING_PORT)
    server.start()

if __name__ == '__main__':
    main()
EOF

    screen -dmS pythonwe python proxy.py -p 80 & || { echo "Erro ao iniciar proxy Python"; exit 1; }
}

# Iniciando o processo de instalação
clear && clear
echo -e "\033[1;31m———————————————————————————————————————————————————\033[1;37m"
echo -e "\033[1;32m             LUCAS WEBSOCKET SSH "
echo -e "\033[1;31m———————————————————————————————————————————————————\033[1;37m"
echo -e "\033[1;37m      WEBSOCKET SSH USARA A PORTA 80 e 443"
echo
echo -e "\033[1;37m                 INSTALANDO SSL... "
fun_bar 'inst_ssl'

echo -e "\033[1;37m                 CONFIGURANDO SSL.. "
fun_bar 'inst_ssl'

echo -e "\033[1;37m                 CONFIGURANDO PYTHON.. "
fun_bar 'inst_py'

echo -e "                 INSTALAÇÃO CONCLUÍDA "
