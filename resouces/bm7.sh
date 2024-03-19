#!/bin/bash

# 检查是否存在规则目录，若不存在，则初始化 git 仓库并拉取规则
if [ ! -d rule ]; then
    git init
    git remote add origin https://github.com/blackmatrix7/ios_rule_script.git
    git config core.sparsecheckout true
    echo "rule/Clash" >> .git/info/sparse-checkout
    git pull --depth 1 origin master
    rm -rf .git # 删除 git 目录，仅保留规则文件
fi

# 移动规则文件到指定目录
list=($(find ./rule/Clash/ | awk -F '/' '{print $5}' | sed '/^$/d' | grep -v '\.' | sort -u))
for ((i = 0; i < ${#list[@]}; i++)); do
    path=$(find ./rule/Clash/ -name ${list[i]})
    mv $path ./rule/Clash/
done

# 对每个规则文件执行处理
list=($(ls ./rule/Clash/))
for ((i = 0; i < ${#list[@]}; i++)); do
    file_prefix="./rule/Clash/${list[i]}/${list[i]}"
    mkdir -p ${list[i]}

    # 处理 Android 包名和进程名，生成 process.json
    if [ -n "$(grep -E 'PROCESS|\.exe' $file_prefix.yaml)" ]; then
        grep -E 'PROCESS|\.exe' $file_prefix.yaml | grep -v '#' | sed 's/  - PROCESS-NAME,//g' > "${list[i]}/process.json"
        echo -e "{\n  \"version\": 1,\n  \"rules\": [\n    {" > "${list[i]}_process.json"
        cat "${list[i]}/process.json" | sed 's/^/        "/g' | sed 's/$/",/g' >> "${list[i]}_process.json"
        echo -e "      }\n  ]\n}" >> "${list[i]}_process.json"
        ./sing-box rule-set compile "${list[i]}_process.json" -o "${list[i]}_process.srs"
        rm "${list[i]}/process.json" "${list[i]}_process.json"
    fi

    # 处理域名，生成 domain.json
    if [ -n "$(grep 'DOMAIN' $file_prefix.yaml)" ]; then
        grep 'DOMAIN' $file_prefix.yaml | grep -v '#' | sed -E 's/  - DOMAIN(-SUFFIX|-KEYWORD)?,//g' > "${list[i]}/domain.json"
        echo -e "{\n  \"version\": 1,\n  \"rules\": [\n    {" > "${list[i]}_domain.json"
        cat "${list[i]}/domain.json" | sed 's/^/        "/g' | sed 's/$/",/g' >> "${list[i]}_domain.json"
        echo -e "      }\n  ]\n}" >> "${list[i]}_domain.json"
        ./sing-box rule-set compile "${list[i]}_domain.json" -o "${list[i]}_domain.srs"
        rm "${list[i]}/domain.json" "${list[i]}_domain.json"
    fi

    # 处理 IP CIDR，生成 ipcidr.json
    if [ -n "$(grep 'IP-CIDR' $file_prefix.yaml)" ]; then
        grep 'IP-CIDR' $file_prefix.yaml | grep -v '#' | sed 's/  - IP-CIDR,//g' | sed 's/  - IP-CIDR6,//g' > "${list[i]}/ipcidr.json"
        echo -e "{\n  \"version\": 1,\n  \"rules\": [\n    {" > "${list[i]}_ipcidr.json"
        cat "${list[i]}/ipcidr.json" | sed 's/^/        "/g' | sed 's/$/",/g' >> "${list[i]}_ipcidr.json"
        echo -e "      }\n  ]\n}" >> "${list[i]}_ipcidr.json"
        ./sing-box rule-set compile "${list[i]}_ipcidr.json" -o "${list[i]}_ipcidr.srs"
        rm "${list[i]}/ipcidr.json" "${list[i]}_ipcidr.json"
    fi

    # 清理临时文件和目录
    rm -rf ${list[i]}
done
