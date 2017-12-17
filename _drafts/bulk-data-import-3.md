---
title: "Bulk data import - part 3"
date: 2017-12-16
categories: redis
---

In previous posts [here]({% post_url 2017-05-26-bulk-data-import2 %}) and [here]({% post_url 2016-03-18-sidekiq-batches %}) I wrote about using Redis for bulk data import.  This article is the next iteration in the series.  

We still want to break up large file into small tasks (one per row or few rows) to make the import faster and more reliable.  And we need to keep track of how many records in the batch imported successfully (or not) to send results to the user.  

Instead of using callbacks and have one job queue others we will implement the process using [gush](https://github.com/chaps-io/gush) library (still use [Ruby on Rails ActiveJob](http://edgeguides.rubyonrails.org/active_job_basics.html)).  We will save the file to S3 in our controller code and pass that ID to our workflow.  

{% highlight ruby %}
# app/controllers/
class ImportController
  def create
    s3_file_object_id = upload_file_to_s3
    flow = ImportWorkflow.create(s3_file_object_id)
    flow.start!
  end
private
  def upload_file_to_s3
    ...
  end
end
{% endhighlight %}

Inside workflow we will download the file locally and queue multiple jobs (one for each row).  We will also define logic to send notification after all imports completed.  

{% highlight ruby %}
# app/workflows/
class ImportWorkflow < Gush::Workflow
  def configure s3_file_object_id
    file_path = download_file(s3_file_object_id)
    csv_jobs = CSV.foreach(file_path).map do |row|
      run ImportCsvRowJob, params: row
    end
    run NotifyUserJob, after: csv_jobs    
  end
private
  def download_file s3_file_object_id
    # return local path
  end
end
{% endhighlight %}

At the end of each `ImportCsvRowJob` we need to store the results on whether it succeeded or failed.  Most likely cause of failure would be invalid data provided by the user who uploaded the file.  

It's important NOT to retry the job (it will fail again) but to record results for input to `NotifyUserJob`.  We will store these results in Redis using `workflow_id` as namespace for the keys.  We will also store the user ID in Redis so we know whom to notify.  

{% highlight ruby %}
# config/initializers/redis.rb
REDIS = Redis.new ...
# app/controllers/
class ImportController
  def create
    ...
    key = "#{flow.id}:current_user"
    REDIS.set(key, current_user.id)
  end
end
class ImportCsvRowJob < Gush::Job
  def perform row
    # validate and save data
    save_results
  end
private
  def save_results
    # create 2 Redis lists: success and error to use appropriately
    key = "#{workflow_id}:success"
    REDIS.lpush(key, row.to_json)
  end
end
{% endhighlight %}

Inside the `NotifyUserJob` we will access these Redis keys, save data to XLSX and send email.  

{% highlight ruby %}
class NotifyUserJob < Gush::Job
  def perform
    # create results_spreadsheet
    REDIS.lrange("#{workflow_id}:success", 0, -1).each do |record|
      results_spreadsheet.add_row(JSON.parse(record))
    end
    # repeat for error list
    current_user = User.find(REDIS.get("#{workflow_id}:current_user"))
    # send email w attachment to current_user.email and set TTL for Redis keys
    ['current_user', 'success', 'error'].each do |key|
      REDIS.expire("#{workflow_id}:#{key}", 1.week)
    end
  end
end
{% endhighlight %}

Keep in mind that gush serializes as JSON all data.  Each job looks like this:

{% highlight ruby %}
{
  "name": "ImportCsvRowJob-64c62ac3-c78a-4e0a-a894-5a3160b2d6a7",
  "klass": "ImportCsvRowJob",
  "incoming": [],
  "outgoing": [
    "NotifyUserJob-bd1cc66e-e5d9-46cd-b981-42957aab38d0"
  ],
  "finished_at": 1513476818,
  "enqueued_at": 1513476786,
  "started_at": 1513476818,
  "failed_at": null,
  "params": ["..."],
  "workflow_id": "898c2c76-cc1c-4e5e-bd53-a8895dfeb8c0",
  "output_payload": null
}
{% endhighlight %}

But each workflow record contains the list of ALL jobs in that workflow so it will get pretty big.  

{% highlight ruby %}
{
  "name": "ImportWorkflow",
  "id": "898c2c76-cc1c-4e5e-bd53-a8895dfeb8c0",
  "arguments": [],
  "total": 1001,
  "finished": 0,
  "klass": "ImportWorkflow",
  "jobs": [
    {
      "name": "ImportCsvRowJob-8fc01ccb-8c64-4a7a-a00c-cc62c47ac079",
      "klass": "ImportCsvRowJob",
      "incoming": [],
      "outgoing": [
        "NotifyUserJob-bd1cc66e-e5d9-46cd-b981-42957aab38d0"
      ],
      "finished_at": null,
      "enqueued_at": null,
      "started_at": null,
      "failed_at": null,
      "params": ["..."],
      "workflow_id": "898c2c76-cc1c-4e5e-bd53-a8895dfeb8c0",
      "output_payload": null
    },
    {
      "name": "ImportCsvRowJob-94dfb81f-17b4-40fe-9a3e-1124c4e004ae",
      "klass": "ImportCsvRowJob",
      ...
    },    
    ...
{% endhighlight %}

It will also slow down as serializing such large JSON strings in our application code takes time.  Serializing complex workflows gives us lots of flexibility but it costs.  
