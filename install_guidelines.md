# mnemospark Install  
The installation of mnemospark needs to be redesigned  

## Install workflow on local device (MacOS/Linux)  

Effects:  
Repo: mnemospark 
Repo: mnemospark-docs


I don't think changes are required in Repo: mnemospark-backend 
But double check to be safe.  

### Directory Structure  
mnemospark uses the .openclaw directory for:  
- logs 
- wallet and wallet key  
- backup file temporary storage  

When OpenClaw installs it creates a .openclaw directory, typically this is in the home directory of the user. 


Note this system change:  
- The command /cloud backup  
- DO NOT use the /tmp directory for file storage  
- Make documentation wide changes to use ./openclaw/mnemospark/backup  
- Update the code in the mnemospark repo to comply with this change  

For example  
/home/ubuntu/.openclaw/mnemospark  
/home/ubuntu/.openclaw/mnemospark/logs  
/home/ubuntu/.openclaw/mnemospark/wallet  
/home/ubuntu/.openclaw/mnemospark/backup  

Or 

/home/<username>/.openclaw/mnemospark  
/home/<username>/.openclaw/mnemospark/logs  
/home/<username>/.openclaw/mnemospark/wallet  
/home/<username>/.openclaw/mnemospark/backup  

Default Install 
- Install command --default  
- Do not check for an existing Blockrun wallet  
- Create a new Ethereum Base blockchain wallet  
- Store the wallet in .openclaw/mnemospark/wallet  
- Secure the private key chmod 600
- After the wallet is installed print the wallet public address to the screen 
- Print to the user "Your new Base blockchain wallet is: <wallet-address>
- Print to the user "Add USDC on the Base network to start using mnemospark today."
- Print to the user "You can acquire USDC on Base from providers like Coinbase and Moonpay"

Standard Install  
- Install command --standard  
- Workflow for standard install  
 - Check to see if a Blockrun wallet exists on the system
 - Check for .openclaw directory 
 - Check for .openclaw/blockrun/wallet.key 
 - If found ask the user if they would like to use the Blockrun wallet 
 - If the user answers "yes" do not create a new wallet, use the Blockrun wallet with mnemospark  
 - If the user answers "no" create a new wallet, follow the steps for the Default Install 