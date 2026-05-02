SimpleAdmin Offline Installer for Airtel ODU

Hey there! If you are trying to get SimpleAdmin running on your Airtel ODU (specifically the SDXLEMUR model), you have probably noticed it can be a huge pain because of the tiny storage space and the locked-down file system. I have put together this offline installer to make the whole process completely painless and automatic.

What this does
Normally, installing Entware and SimpleAdmin fails on these Airtel devices because the data partition is capped at 18.2 MB and the system locks you out of adding custom boot services. This installer fixes all of that behind the scenes. It automatically sets up a RAMdisk to run the environment smoothly and uses a clever workaround to make sure your settings and dashboard survive every reboot.

One-Click Installation Steps
We have made this as simple as possible. You do not need an active internet connection on the router to make this work.

Step 1
Connect your device to your computer via USB and make sure ADB is enabled and authorized.

Step 2
Double click the simpleadmin_offline.bat file on your Windows computer.

Step 3
Sit back and wait. The script will automatically download the necessary files to your computer, push them over to your router, bypass the storage limits, and set up all the required services.

Step 4
Once the script finishes, your router will automatically restart.

Step 5
That is it! You can now access your new SimpleAdmin dashboard by opening your web browser and going to https://192.168.1.1:8443

Default Login
Username: admin
Password: Asdf@12345

Enjoy your fully unlocked dashboard!
