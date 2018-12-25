---
title: "Managing dynamic inventory in the cloud with Ansible"
date: 2018-12-24
categories: ansbile terraform
---

Ansible is a useful tool for provisioning infrastructure (instaling software, modifying config files).  Usualy Ansible expects an inventory file which specifies servers and their IP addresses.  The challenge is that in the cloud they can change frequently.  

One option is to use a product like Ansible Tower which maintains a database of the inventory it manages.  Instead we will expore how to query cloud provider APIs and detetermine the current state of our infrastructure. 

* TOC
{:toc}

## Static inventory

Here is a sample inventory file.  As long as our inventory is small and fairly static we can copy and paste the IP addresses.  

{% highlight yaml %}
web:
  hosts:
    1.1.1.1:
    2.2.2.2:
worker:
  hosts:
    3.3.3.3:
...
{% endhighlight %}

Then in our playbooks we specify `web` or `worker` as `hosts`.  

{% highlight yaml %}
---
- hosts: worker
  tasks:
  ...
{% endhighlight %}

## Dynamic inventory

This approach becomes impractical as our inventory grows and instances launch and terminate in the cloud.  For this example we will use Oracle Cloud and a dynamic inventory Python script provided as part of `oci-ansible-modules` project (we will not be using other features from that project).

When we execute `ansible-playbook -i oci_inventory.py my_playbook.yml` we reference the dynamic inventory with `-i`.  It will query the clould APIs and generate local `ansible-oci.cache` file.  

{% highlight json %}
{
  ...
  "_meta": {
    "hostvars": {
      "1.1.1.1": {
        "availability_domain": "...",
        "compartment_id": "",
        "defined_tags": {},
        "display_name": "...",
        "extended_metadata": {},
        "fault_domain": "...",
        "freeform_tags": {
          "app_name": "app1",
          "env": "prod",
          "server_role": "web"
        },
      },
    },
  "tag_app_name=app1": {
    "hosts": [
        ...
    ]
  },
  "tag_env=prod": {
    "hosts": [
        ...
    ]
  },
  "tag_server_role=web": {
    "hosts": [
        ...
    ]
  },
  ...
}
{% endhighlight %}

By default if the file is older than 5 minutes the `oci_inventory.py` will query the cloud APIs again and regenerate the it.  We can also specify several filtering options in case we want to manage only a portion of our cloud infrastructure.  

## Tags

Now we need to be able to run different playbooks on different servers.  For that we will use tags.  When we create our cloud infrastructure we tag our instances.  Here is a Terraform example:

{% highlight bash %}
resource "oci_core_instance" "app1_web_prod" {
  ...
  freeform_tags = {
    app_name    = "app1"
    server_role = "web"
    env         = "prod"
  }  
}
{% endhighlight %}

We can see our instances grouped by tags in the `ansible-oci.cache`.  Now in our playbooks we can specify:

{% highlight yaml %}
---
- name : provision web servers
  hosts: tag_server_role=web
  tasks:
  ...
{% endhighlight %}

## Control server

We do not want to manage our infrastructure from a dev laptop.  Instead we will setup a control server where these processes can be executed periodically to ensure that newly created instances are properly provisioned.  

We can use Ansible playbook to provision this server.  Ansible itself can be installed via various package managers which can be executed from a playbook.  We tag the instance:

{% highlight bash %}
resource "oci_core_instance" "ansible_control" {
  ...
  freeform_tags = {
    app_name    = "ansible"
    server_role = "control"
  }  
}
{% endhighlight %}

And then manually execute from our dev laptop: 

{% highlight yaml %}
---
- name : provision ansible control server
  hosts: tag_app_name=ansible:&tag_server_role=control    
  tasks:
  ...
  - name: install os packages
    become: yes
    package:
      name: 
        - ansible
        - rsync
  - name: upload creds files
    copy:
      ...
  - name: rsync playbooks and other files
    synchronize:
      ...
  - name: cron for running playbooks
    cron:
    ...
{% endhighlight %}

Now the control server will query the cloud APIs on schedule, update local inventory cache and do appropriate provisioning of other servers in our fleet.  

## Summary

This approach is far from perfect.  There is no easy way to monitor when a scheduled Ansible run fails.  Our control server is a singleton.  There could be scalability challenges once we are managing hundreds or thousands of servers.  

Another improvement is for instance to somehow notify the control server when it launches. This way provisioning can be done right away without waiting for the next scheduled Ansible run.  Also control server could be setup to automatically provision itself via some kind of `cloud-init` process.  

The advantage of this design is simplicity.  The only "moving part" is the cron on the control server.  There is no need for database to maintain state, no need for agents to run on the instances.  Ansible is agentless and mostly idempotent which means we can run our tasks repeatedly.  Once an instance is provisioned re-running the same playbook on it takes very little time so we can schedule the process to run as frequently as every 5 minutes.  

## Links
* Dynamic inventory - https://github.com/oracle/oci-ansible-modules/tree/master/inventory-script
* Repo with examples for this solution https://github.com/dmitrypol/oci_ansible_modules
* https://docs.ansible.com/ansible/latest/user_guide/intro_dynamic_inventory.html
* https://docs.ansible.com/ansible/latest/dev_guide/developing_inventory.html
* https://docs.ansible.com/ansible/latest/plugins/inventory.html