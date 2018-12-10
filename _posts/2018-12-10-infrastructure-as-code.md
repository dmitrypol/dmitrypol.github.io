---
title: "Infrastructure as Code with Packer, Ansible and Terraform"
date: 2018-12-10
categories: packer ansbile terraform
---

This article is meant demonstrate one possible way of integrating Packer, Ansible and Terraform.  It assumes that the reader is somewhat familiar with these (or similar) tools.  For more in depth info on each tool please consult other resources.  

When building modern software applications we often follow MVC pattern reinforced by different frameworks.  We have varous layers (DB, ORM, controlers, UI templaters, etc).  And while we could hardcode SQL query in our presentation layer it is not a good long term solution.  

With Infrastructure as Code we also have various layers.  We have base images, we need to provision them (create folders / files, install software, etc).  And we need to be able to manage them reliably at scale.  In this article we will expore how to use Packer, Ansible and Terraform for this purpose.  

* TOC
{:toc}

## Packer

Packer is an open source tool for creating identical machine images for multiple platforms from a single source configuration.  We can run it like this `packer build packer_example.json` using exampe below.  

{% highlight json %}
{
  "builders": [
    {
      "availability_domain": "...",
      "base_image_ocid": "...",
      "compartment_ocid": "...",
      "image_name": "my_new_image",
      "shape": "{ { user `shape`} }",
      "ssh_username": "opc",
      "subnet_ocid": "...",
      "type": "oracle-oci"
    }
  ],
  "provisioners": [
    {
      "inline": [
        "sleep 1",
        "sleep 1"
      ],
      "type": "shell"
    },
    {
      "playbook_file": "packer_playbook.yml",
      "type": "ansible",
      "user": "opc"
    }
  ],
  "variables": {
    "shape": "VM.Standard2.1"
  }
}
{% endhighlight %}

### Builders

We are using `oracle-oci` as `type` of builder.  Packer also supports different builders for various cloud platforms.  We need to specify various parameters such as `base image`, `ssh username`, etc.  

We also need to specify the credentials that Packer will use to communicate with Oracle Cloud APIs.  In this case Packer will use the default creds in `~/.oci/config` file but that may vary depending on the cloud builder.  

### Variables

We can either hard code various params in the builders section or set variables and reference them.  We also can use environment variables in case we do not want to put sensitive info in these files as they will be committed to our source code repository.

### Provisioners - bash

Once we launch an instance from the base image we need to execute our provisioning steps before it saved to a new image.  For simple tasks we can use inline bash commands or reference external `.sh` files.  In the example above we execute sleep statements for demo purposes.

### Provisioners - Ansible

For more complex provisioning we can use a tool like Ansible.  Here is a `packer_playbook.yml` that we referenced in `packer_example.json`.  It will install specific versions of Redis and Nginx and then stop those services.  

{% highlight yaml %}
---
- hosts: default
  become: yes

  tasks:

  - name: install packages
    package:
      name:
        - nginx-1.12.2
        - redis-3.2.12
      state: present

  - name: stop services
    service:
      name: "{ { item } }"
      state: stopped
    loop:
      - nginx
      - redis
{% endhighlight %}

#### Testing the playbook

The process of launching an instance, running playbook and saving a new image can take 5-10 minutes.  To speed up the process we can launch a separate instance from the same base image, test the playbook via Ansible directly, verify the provisioning steps and then use the playbook via Packer.  

Another option is to run `packer build -debug packer_example.json` which will pause at every step.  This allows us to SSH to the instance while it's running and verify the provisoning steps.  

## Terraform

The output of the Packer build process will be an image ID which can be used to launch instances via Terraform.  Terraform supports many cloud providers but below we will be using examples with Oracle Cloud.  

### Creating a module

To keep our config files DRY we will first create this Terraform module `main.tf` file.

{% highlight bash %}
variable "image_source_id" {
  default = "ocid1.image.oc1.PACKER_IMAGE_HERE"
}

variable "freeform_tags" {
  type = "map"
  default = {}
}

variable "count" {
  default = 1
}

variable "shape" {
  default = "VM.Standard2.1"
}

variable "ssh_public_key_file" {
  default = "~/.ssh/id_rsa.pub"
}

provider "oci" {
  version          = ">= 3.0.0"
  tenancy_ocid     = "..."
  user_ocid        = "..."
  fingerprint      = "..."
  private_key_path = "~/.oci/oci_api_key.pem"
  region           = "us-ashburn-1"
}

resource "oci_core_instance" "default" {
  count               = "${var.count}"
  availability_domain = "..."
  compartment_id      = "..."
  shape               = "${var.shape}"
  subnet_id           = "..."
  source_details {
    source_type = "image"
    source_id   = "${var.image_source_id}"
  }

  metadata {
    ssh_authorized_keys = "${file(var.ssh_public_key_file)}"
  }

  freeform_tags = "${var.freeform_tags}"
}

output "ip_output" {
  value = "${oci_core_instance.default.*.public_ip}"
}
{% endhighlight %}

### Leveraging module

Now we can leverage the module above from another `main.tf`: 

{% highlight bash %}
module "web" {
  source = "modules_path/"
  count  = 2
  freeform_tags = {
    server_role = "web"
  }
}

output "web_ip_output" {
  value = "${module.web.ip_output}"
}

module "worker" {
  source = "modules_path/"
  count  = 1
  freeform_tags = {
    server_role = "worker"
  }
}

output "worker_ip_output" {
  value = "${module.worker.ip_output}"
}
{% endhighlight %}

When we run `terrafrom apply` this will launch 1 worker and 2 web servers.  Some of the params are hardcoded in the module but others can be configured via variables.  

Here we are specifying many of the same cloud provider specific info as we did with Packer.  To keep things DRY we could extract these attributers into environmental variables.  

## Ansible

Once our `web` and `worker` servers are launched we need to do additional provisioning.  We need to launch Nginx service on the `web` and Redis service on `worker` servers.  

We create `web.yml`:

{% highlight yaml %}
---
- hosts: web
  become: yes

  tasks:

  - name: start services
    service: 
      name: nginx
      enabled: yes
      state: started
  ...
{% endhighlight %}

And `worker.yml`:

{% highlight yaml %}

---
- hosts: worker
  become: yes

  tasks:

  - name: start services
    service: 
      name: redis
      enabled: yes
      state: started
  ...
{% endhighlight %}

### Inventory

We also need a `hosts.yml` file specifying IP addresses of the instances:

{% highlight yaml %}
web:
  hosts:
    1.1.1.1:
    2.2.2.2:
worker:
  hosts:
    3.3.3.3:
{% endhighlight %}

Now we can run `ansible-playbook -i hosts.yml web.yml worker.yml` which will perform the tasks specified on the appropriate servers.  We also can add other steps such instaling other packages, creating folders and deploying our code.  

## Summary

Creating one image with pre-installed Redis and Nginx simplifies our processes.  If we need to update security patches or install new version of Redis / Nginx we simply modify the Packer JSON file and re-run it.  Then we use the new image in the Terraform step.  Finally Ansible step enables the services we need on the appropriate instances.  

Using tools like Packer, Ansible and Terraform automates manual processes and significantly increases our productivity.  We can also version control the YML, TF and JSON files.  And this helps reuse more of our code by extracting logic in Terraform modules or Ansilble roles.  

One downside is there is some overlap between these tools.  For example, Terraform can use cloud-init provisioner instead of Ansible.  The tools also use different formats / commands.  Hopefully with time we will come up with more unified standards.  

## Links
* https://www.packer.io/docs/builders/oracle-oci.html
* https://www.packer.io/docs/provisioners/ansible-local.html
* https://www.terraform.io/docs/providers/oci/index.html 
* https://registry.terraform.io/ 
* https://docs.ansible.com/ansible/latest/index.html 
* https://github.com/oracle/oci-ansible-modules/tree/master/inventory-script