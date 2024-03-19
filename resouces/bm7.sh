#!/bin/bash

# 拉取规则文件
if [ ! -d rule ]; then
    git init
    git remote add origin https://github.com/blackmatrix7/ios_rule_script.git
    git config core.sparsecheckout true
    echo "rule/Clash" >> .git/info/sparse-checkout
    git pull --depth 1 origin master
    rm -rf .git
fi

# 定义需要保留的文件列表
declare -a keep_files=("ChinaMax.yaml" "TelegramUS.yaml" "Gemini.yaml" "OpenAI.yaml" "Claude.yaml" "Telegram.yaml" "Proxy.yaml" "GlobalMedia.yaml" "Global.yaml" "Microsoft.yaml" "Apple.yaml")

# 移动文件到 Clash 目录，并删除不在列表中的文件
find ./rule/Clash/ -type f -name "*.yaml" -exec mv {} ./rule/Clash/ \;
cd ./rule/Clash/
ls *.yaml | while read filename; do
    if [[ ! " ${keep_files[@]} " =~ " ${filename} " ]]; then
        rm -f "$filename"
    fi
done

# 处理规则文件
for yaml_file in ./rule/Clash/*.yaml; do
    base_name=$(basename "$yaml_file" .yaml)

    # 生成针对 Android 包名和进程名的 JSON
    grep -E 'PROCESS-NAME' "$yaml_file" | grep -v '#' | sed 's/  - PROCESS-NAME,//g' > temp.json
    if [ -s temp.json ]; then
        echo -e "{\n  \"version\": 1,\n  \"rules\": [\n    {\"process_name\": [" > "${base_name}_process.json"
        sed 's/^/        "/;s/$/",/' temp.json >> "${base_name}_process.json"
        echo -e "      ]}\n  ]\n}" >> "${base_name}_process.json"
        ./sing-box rule-set compile "${base_name}_process.json" -o "${base_name}_process.srs"
    fi
    rm -f temp.json

    # 生成针对域名的 JSON
    grep -E 'DOMAIN(-SUFFIX|-KEYWORD)?,' "$yaml_file" | grep -v '#' | sed -E 's/  - DOMAIN(-SUFFIX|-KEYWORD)?,//g' > temp.json
    if [ -s temp.json ]; then
        echo -e "{\n  \"version\": 1,\n  \"rules\": [\n    {\"domain\": [" > "${base_name}_domain.json"
        sed 's/^/        "/;s/$/",/' temp.json >> "${base_name}_domain.json"
        echo -e "      ]}\n  ]\n}" >> "${base_name}_domain.json"
        ./sing-box rule-set compile "${base_name}_domain.json" -o "${base_name}_domain.srs"
    fi
    rm -f temp.json

    # 生成针对 IP CIDR 的 JSON
    grep 'IP-CIDR,' "$yaml_file" | grep -v '#' | sed 's/  - IP-CIDR,//g' > temp.json
    if [ -s temp.json ]; then
        echo -e "{\n  \"version\": 1,\n  \"rules\": [\n    {\"ip_cidr\": [" > "${base_name}_ipcidr.json"
        sed 's/^/        "/;s/$/",/' temp.json >> "${base_name}_ipcidr.json"
        echo -e "      ]}\n  ]\n}" >> "${base_name}_ipcidr.json"
        ./sing-box rule-set compile "${base_name}_ipcidr.json" -o "${base_name}_ipcidr.srs"
    fi
    rm -f temp.json
done
