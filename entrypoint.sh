#!/bin/bash

# sudo docker logs [container_name] 으로 로그 확인 가능
echo "hello entrypoint!"

# MOTD 설정
echo -e "\n\n -------------------------------------------------------------------------------------------------------------------------------------------- 
\n\n 안녕하세요. 동국대학교 AI lab 입니다. \n\n 해당 컨테이너는 sudo권한을 가집니다. 
\n 따라서, 컨테이너 또는 컨테이너가 실행중인 로컬서버에 해가 되는 행동을 할 시 사용자분에게 전적인 책임이 있음을 안내드립니다. 
\n 디렉토리 또는 파일을 삭제하는 행위 또는 root 권한을 통해 시스템을 수정하는 명령어 등을 조심히 사용해주시기 바랍니다. 감사합니다. \n\n 
--------------------------------------------------------------------------------------------------------------------------------------------\n" > /etc/motd

# 유저 계정 생성
if ! id "$USER_ID" >/dev/null 2>&1; then
    echo "No User account detected..."

    # 유저 계정을 생성, 홈폴더는 decs폴더로 설정
    useradd -s /bin/bash -d /$USER_ID $USER_ID
    # sudo 권한을 주되, 자신 소유가 아닌 폴더를 삭제하는 shell command를 제한
    echo "$USER_ID ALL=(ALL) NOPASSWD:ALL, !/bin/rm" >> /etc/sudoers

    # 홈폴더 생성
    # skeleton 파일을 복사하여, 유저명이 tf-docker 로 표시되는 것을 방지
    mkdir "/home/public/$USER_ID"
    cp -R /etc/skel/. "/home/public/$USER_ID"
    usermod -d "/home/public/$USER_ID" "$USER_ID"

    # 입력받은 비밀번호로 유저 계정 변경
    echo "$USER_ID:$USER_PW" | chpasswd

    echo "user account config done..."
    
    # sshd 설정도 바꾼다.
    # 서버관리자와 유저계정의 ssh 접속을 허용
    sed -i "/^#PermitRootLogin/a AllowUsers svmanager" /etc/ssh/sshd_config
    sed -i "/^#PermitRootLogin/a AllowUsers $USER_ID" /etc/ssh/sshd_config

    # 사용자가 한명만 접속이 되고, 다른 사용자는 접속이 불가능 한 현상을 해결하기 위해 PAM 기능을 비활성화
    sed -i 's/^UsePAM yes/UsePAM no/' /etc/ssh/sshd_config

    # Motd 를 출력하도록 설정
    sed -i 's/^#* *PrintMotd.*$/PrintMotd yes/' /etc/ssh/sshd_config

    service ssh restart
    echo "ssh change done..."

fi

### start 그룹 기능 비활성화 하였음 (2023-07-17 전재호)

# # 그룹 기능(여러 사용자가 동일한 폴더에 접근 가능)
# # 그룹 폴더가 없는 경우(신규 그룹) 생성
# if [ ! -d "/home/public/$USER_GROUP/" ]; then
#   # 폴더 생성
#   mkdir /home/public/$USER_GROUP
#   echo "Created /home/public/$USER_GROUP...."
# fi

# # 그룹 추가, 등록, 권한 설정
#   groupadd $USER_GROUP
#   usermod -aG $USER_GROUP $USER_ID
#   usermod -d /home/public $USER_ID
#   # 그룹의 공유 디렉토리의 모든 파일의 소유권 설정
#   chown -R svmanager:$USER_GROUP /home/$USER_GROUP
#   chmod -R 770 /home/$USER_GROUP

#   # 그룹의 공유 디렉토리의 권한 설정
#   chmod g+rw /home/$USER_GROUP
#   echo "Group Permission Setting done"

### end 그룹 기능 비활성화 하였음 (2023-07-17 전재호)

# UID, GID 설정 (UID가 기본적으로 1001로 시작되는데, 컨테이너끼리 겹치면 접근 제한 불가)
groupmod -g $UID $USER_ID
usermod -u $UID -g $UID $USER_ID

# # readme 안내문 생성
# echo "Hello Decs, 동국대학교 GPU 서버 컨테이너 서비스 decs 입니다." > /home/$USER_ID/readme_decs.txt

# jupyterlab 설정파일 수정

# # jupyter lab 에서 생성한 ipynb 파일을 저장할 디렉토리 생성 (없는경우만 신규 생성)
# if [ ! -d "/home/$USER_ID/decs_jupyter_lab" ]; then
#   mkdir /home/$USER_ID/decs_jupyter_lab
#   echo "Created /home/$USER_ID/decs_jupyter_lab dir...."
# fi

# # jupyter lab 접속 설정
# sed -i "1i c.JupyterApp.config_file_name = 'jupyter_notebook_config.py'\nc.NotebookApp.allow_origin = '*'\nc.NotebookApp.ip = '0.0.0.0'\nc.NotebookApp.open_browser = False\nc.NotebookApp.allow_remote_access = True\nc.NotebookApp.allow_root = True\nc.NotebookApp.notebook_dir='/home/$USER_ID/decs_jupyter_lab'" /jupyter_config/jupyter_notebook_config.py

# # jupyter_lab 기동
# echo "trying jupyter lab..."
# nohup /opt/anaconda3/bin/jupyter lab --NotebookApp.token=decs --config=/jupyter_config/jupyter_notebook_config.py >/dev/null 2>&1 &
# echo "jupyter lab listening!"

# xrdp의 터미널이 안켜지는 오류 자동 해결 : 터미널로 xface 를 선택
# update-alternatives --set x-terminal-emulator /usr/bin/xfce4-terminal

# # xrdp를 자동으로 시작
# service xrdp-sesman start
# service xrdp start

# 유저 개인폴더 안에 프로그램을 모두 설치하고 나면, 유저 개인폴더의 모든 파일의 소유자를 유저로 변경. 시간이 약간 소요됨(재귀로 모든 파일의 권한을 변경.)
chown -R "$UID:$UID" "/home/public/$USER_ID"
chmod -R 700 "/home/public/$USER_ID"
echo "decs chown change done..."

# # 재시작 오류를 자동으로 해결
# pid_file="/var/run/xrdp/xrdp.pid"
# if [ -f "$pid_file" ]; then
#     rm -f "$pid_file"
# fi
# sesman_file="/var/run/xrdp/xrdp-sesman.pid"
# if [ -f "$sesman_file" ]; then
#     rm -f "$sesman_file"
# fi


#entrypoint.sh 를 실행하고 나서 컨테이너가 Exit 하지 않게함
tail -F /dev/null
