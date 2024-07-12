#!/usr/bin/env bash

# export PATH="/opt/homebrew/opt/python@3.9/libexec/bin:$PATH"
pip3 install --upgrade pip
python3 -m pip install --user pipx
python3 -m pipx ensurepath
pipx install virtualenv
pipx install awscli
python3 -m venv venv
# shellcheck disable=SC1091
. venv/bin/activate
pip install -r requirements.txt
ansible-galaxy install -r ansible/ansible_requirements.yml

if [ ! -d "${HOME}/.aws" ]
then
    echo "${HOME}/.aws does not exist"
    echo "you need to make sure you awscli is correctly configured... invoking configure"
    aws configure
fi
