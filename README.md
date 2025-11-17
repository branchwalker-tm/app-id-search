# app-id-seach

A simple bash script that grabs your App-ID cache from your firewall and searches it for the string you are looking for. Useful if you are trying to reconcile app names between platforms.

1. Clone the repo
2. `chmod +x app_stats_search.sh`
3. Edit the script using your preferred text editor and replace `<YOUR_FIREWALL_IP_OR_HOSTNAME>` and `<YOUR_API_KEY>` with the information relevant to your environment.
4. *TIP*: Generate your API key buy running `curl -k -X POST 'https://<firewall_or_panorama_ip_or_hostname>/api/?type=keygen' -d 'user=<username>&password=<password>'`
5. To run, simply invoke `./app_stats_search.sh input_csv.csv output.csv`
