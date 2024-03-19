#!/bin/bash

# 定义规则文件的存放目录
rule_dir="rule/Clash"

# 如果目录不存在，则创建目录
if [ ! -d "$rule_dir" ]; then
    mkdir -p "$rule_dir"
fi

# 定义需要下载的规则文件链接
declare -a urls=(
"https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Apple/Apple_Classical.yaml"
"https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Proxy/Proxy_Classical.yaml"
"https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Global/Global_Classical.yaml"
"https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/GlobalMedia/GlobalMedia_Classical.yaml"
"https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/ChinaMax/ChinaMax_Classical.yaml"
"https://gitlab.com/lodepuly/vpn_tool/-/raw/master/Tool/Clash/Rule/OpenAI.yaml"
"https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Microsoft/Microsoft.yaml"
"https://gitlab.com/lodepuly/vpn_tool/-/raw/master/Tool/Loon/Rule/TelegramALL.list"
"https://gitlab.com/lodepuly/vpn_tool/-/raw/master/Tool/Loon/Rule/TelegramUS.list"
"https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Gemini/Gemini.yaml"
"https://raw.githubusercontent.com/blackmatrix7/ios_rule_script/master/rule/Clash/Claude/Claude.yaml"
)

# 下载规则文件
for url in "${urls[@]}"; do
    filename=$(basename "$url")
    # 使用curl命令下载文件
    curl -L "$url" -o "${rule_dir}/${filename}"
done

# 处理规则文件
for yaml_file in "$rule_dir"/*.yaml; do
    base_name=$(basename "$yaml_file" .yaml)

    # 初始化JSON结构
    echo -e "{\n  \"version\": 1,\n  \"rules\": [\n    {\n      \"domain_suffix\": [],\n      \"domain_keyword\": [],\n      \"domain\": []\n    }\n  ]\n}" > "${base_name}_domain.json"
    
    # 分析并处理每个规则
    while IFS= read -r line; do
        if [[ "$line" =~ DOMAIN-SUFFIX,(.*) ]]; then
            # 处理 DOMAIN-SUFFIX
            domain_suffix="${BASH_REMATCH[1]}"
            jq --arg domain_suffix "$domain_suffix" '.rules[0].domain_suffix += [$domain_suffix]' "${base_name}_domain.json" > "temp_${base_name}_domain.json" && mv "temp_${base_name}_domain.json" "${base_name}_domain.json"
        elif [[ "$line" =~ DOMAIN-KEYWORD,(.*) ]]; then
            # 处理 DOMAIN-KEYWORD
            domain_keyword="${BASH_REMATCH[1]}"
            jq --arg domain_keyword "$domain_keyword" '.rules[0].domain_keyword += [$domain_keyword]' "${base_name}_domain.json" > "temp_${base_name}_domain.json" && mv "temp_${base_name}_domain.json" "${base_name}_domain.json"
        elif [[ "$line" =~ DOMAIN,(.*) ]]; then
            # 处理 DOMAIN
            domain="${BASH_REMATCH[1]}"
            jq --arg domain "$domain" '.rules[0].domain += [$domain]' "${base_name}_domain.json" > "temp_${base_name}_domain.json" && mv "temp_${base_name}_domain.json" "${base_name}_domain.json"
        fi
    done < "$yaml_file"

    # 生成针对 Android 包名和进程名的 JSON
    grep -E 'PROCESS-NAME' "$yaml_file" | grep -v '#' | sed 's/  - PROCESS-NAME,//g' > temp.json
    if [ -s temp.json ]; then
        echo -e "{\n  \"version\": 1,\n  \"rules\": [\n    {\"process_name\": [" > "${base_name}_process.json"
        sed 's/^/        "/;s/$/",/' temp.json >> "${base_name}_process.json"
        echo -e "      ]}\n  ]\n}" >> "${base_name}_process.json"
        ./sing-box rule-set compile "${base_name}_process.json" -o "${base_name}_process.srs"
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
