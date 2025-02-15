# Personal ProxmoxScripts
My personal Proxmox Helper Scripts inspired by the [Proxmox community scripts](https://github.com/community-scripts/ProxmoxVE/)
 
—

## 🚀 Project Overview

**Proxmox Scripts** is a collection of tools to simplify the setup and management of Proxmox Virtual Environment (VE). This is to simplify reoccurring tasks or create own versions of existing scripts


## 📦 Features
 
— Complete setup of a new container (map root user, create login user, disable root shell in container, create volume mapping with corresponding access rights)
- Updater/Installer with single download: easily check what you get in advance

## ✅ Requirements

Ensure your system meets the following prerequisites:

- **Proxmox VE version**: 8.x or higher
- **Linux**: Compatible with most distributions
- **Dependencies**: bash and curl should be installed.


## 🚀 Installation / Updates

To install clone the repo or run the following  ommand

https://raw.githubusercontent.com/KriGosSa/ProxmoxScripts/refs/heads/main/setup.sh

```bash
source <(wget -qLO - https://github.com/KriGosSa/ProxmoxScripts/raw/main/install.func) && install_script
```


<div class=“code-box”>
  <pre><code id=“codeBlock”>bash -c “$(wget -qLO - https://github.com/KriGosSa/ProxmoxScripts/raw/main/install.func) install”</code></pre>
  <button class=“copy-btn” onclick=“copyToClipboard()”>Copy</button>
</div>

<script>
function copyToClipboard() {
  var code = document.getElementById(“codeBlock”);
  var range = document.createRange();
  range.selectNode(code);
  window.getSelection().removeAllRanges();
  window.getSelection().addRange(range);
  document.execCommand(‘copy’);
  alert(‘Copied to clipboard!’);
}
</script>

## 🤝 Report a Bug or Feature Request

If you encounter any issues or have suggestions for improvement, file a new issue on our [GitHub issues page](https://github.com/KriGosSa/ProxmoxScripts/issues). You can also submit pull requests with solutions or enhancements!

But be aware: this is a personal hobby script collection (I have a day job and a Family) so reaction times might be longer.

—

## 📜 License

This project is licensed under the [MIT License](LICENSE).

</br>
</br>
<p align=“center”>
  <i style=“font-size: smaller;”><b>Proxmox</b>® is a registered trademark of <a href=“https://www.proxmox.com/en/about/company”>Proxmox Server Solutions GmbH</a>.</i>
</p>