# lb-cloud-deployment-automation
A script to automate the 'manual' configuration and deployment of Lightbits in the cloud.

## Scripts
[install_lightbits.sh](./install_lightbits.sh)

## Use

### Install Lightbits (Configure Mode)
> **_NOTE:_** This script must be run on a RHEL 8/Alma 8 instance.

This script will configure the ansible files for a given cloud storage VM. It works for both AWS and Azure.

1. Ensure that git has been installed on the installer: `sudo yum install -y git`
2. Download file onto installer: `git clone https://github.com/felixm-lb/lb-cloud-deployment-automation.git`
3. Run:
   1. With user/password authentication: `sudo bash lb-cloud-deployment-automation/install_lightbits.sh -m configure -n l16s_v3 -i "10.0.0.1,10.0.0.2,10.0.0.3" -u azureuser -p 'password' -t QWCEWVDASADSSsSD -v lightos-3-2-1-rhl-86 -c test-cluster`
   2. With key authentication: `sudo bash lb-cloud-deployment-automation/install_lightbits.sh -m configure -n i3en.6xlarge -i "10.0.0.1,10.0.0.2,10.0.0.3" -u ec2-user -k /home/ec2-user/key.pem -t QWCEWVDASADSSsSD -v lightos-3-2-1-rhl-86 -c test-cluster`

### Install Lightbits (Installer Mode)
> **_NOTE:_** This script must be run AFTER the install_lightbits.sh -m configure has been run. Essentially, Ansible needs to be good to go and the targets configured.

This script will run the ansible playbooks to install Lightbits via a docker container.

1. Run: `sudo bash lb-cloud-deployment-automation/install_lightbits.sh -m install -c test-cluster -v lightos-3-2-1-rhl-86`

## License, Warranty, Support, and Contact Information
These tools are provided for convenience and maintaned outside of the Lightbits DevOps process and therefore are not maintained as a part of the Lightbits codebase.

If you received these tools from Lightbits Labs, you are covered under the terms of your license and support agreement provided by Lightbits. Contact info (at) lightbitslabs.com for any questions or support. In all other cases, the following disclaimer applies:

THIS REPOSITORY IS PROVIDED BY LIGHTBITS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL LIGHTBITS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES, LOSS OF USE, LOSS AND/OR CORRUPTION OF DATA, LOST PROFITS, OR BUSINESS INTERRUPTION) OR ANY OTHER LOSS HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS REPOSITORY, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

For more information, queries or comments, please contact felix@lightbitslabs.com
