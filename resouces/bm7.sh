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
        
    # 创建一个新的JSON文件
    json_file="${base_name}_domain.json"
    echo -e "{\n  \"version\": 1,\n  \"rules\": [\n    {\n      \"domain_suffix\": [],\n      \"domain_keyword\": [],\n      \"domain\": []\n    }\n  ]\n}" > "$json_file"

    # 使用grep提取并处理域名相关规则，然后将结果直接插入到JSON文件中
    domain_suffixes=$(grep -oE 'DOMAIN-SUFFIX,([^,]+)' "$yaml_file" | cut -d',' -f2 | awk '{print "        \"" $0 "\","}' | sed '$ s/,$//')
    domain_keywords=$(grep -oE 'DOMAIN-KEYWORD,([^,]+)' "$yaml_file" | cut -d',' -f2 | awk '{print "        \"" $0 "\","}' | sed '$ s/,$//')
    domains=$(grep -oE 'DOMAIN,([^,]+)' "$yaml_file" | cut -d',' -f2 | awk '{print "        \"" $0 "\","}' | sed '$ s/,$//')

    if [[ -n $domain_suffixes || -n $domain_keywords || -n $domains ]]; then
        # 插入提取的规则到JSON
        sed -i "/\"domain_suffix\": \[/a\ $domain_suffixes" "$json_file"
        sed -i "/\"domain_keyword\": \[/a\ $domain_keywords" "$json_file"
        sed -i "/\"domain\": \[/a\ $domains" "$json_file"
    fi

    # 生成针对 Android 包名和进程名的 JSON
    if grep -q 'PROCESS-NAME,' "$yaml_file"; then
        grep -E 'PROCESS-NAME' "$yaml_file" | grep -v '#' | sed 's/  - PROCESS-NAME,//g' > temp_process.json
        if [ -s temp_process.json ]; then
            echo -e "{\n  \"version\": 1,\n  \"rules\": [\n    {\"process_name\": [" > "${base_name}_process.json"
            sed 's/^/        "/;s/$/",/' temp_process.json >> "${base_name}_process.json"
            echo -e "      ]}\n  ]\n}" >> "${base_name}_process.json"
        fi
        rm -f temp_process.json
    fi

    # 生成针对 IP CIDR 的 JSON
    if grep -q 'IP-CIDR,' "$yaml_file"; then
        grep 'IP-CIDR,' "$yaml_file" | grep -v '#' | sed 's/  - IP-CIDR,//g' > temp_ipcidr.json
        if [ -s temp_ipcidr.json ]; then
            echo -e "{\n  \"version\": 1,\n  \"rules\": [\n    {\"ip_cidr\": [" > "${base_name}_ipcidr.json"
            sed 's/^/        "/;s/$/",/' temp_ipcidr.json >> "${base_name}_ipcidr.json"
            echo -e "      ]}\n  ]\n}" >> "${base_name}_ipcidr.json"
        fi
        rm -f temp_ipcidr.json
    fi
done
