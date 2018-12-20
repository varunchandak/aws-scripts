def lambda_handler(event, context):
    # TODO implement
    import boto3
    import datetime

    client = boto3.client('ec2')
    regions = [region['RegionName'] for region in client.describe_regions()['Regions']]
    for regionnaire in regions:
        print regionnaire
        ec2 = boto3.client("ec2", region_name=regionnaire)
        instances_list =  ec2.describe_instances()
        nowtime = datetime.datetime.now().strftime('%d%m%Y-%H-%M')
        for reservation in instances_list['Reservations']:
            for instance in reservation['Instances']:
                ami = False
                reboot = False
                retention = 7
                # UTC Time for IST Zone
                timeToCreate = "18:30"
                instanceName = "Unnamed"
                if instance.get("Tags",None) != None:
                    tags = instance["Tags"]
                    for tag in tags:
                        if(tag["Key"] == "AMIBackup" and tag["Value"] == "Yes"):
                            ami = True
                        if(tag["Key"] == "Reboot" and tag["Value"] == "Yes"):
                            reboot = True
                        if(tag["Key"] == "AMITime"):
                            timeToCreate = tag["Value"]
                        if(tag["Key"] == "Retention"):
                            retention = tag["Value"]
                        if(tag["Key"] == "Name"):
                            instanceName = tag["Value"]
                    if(ami==True):
                        timeToCreate = datetime.datetime.strptime(timeToCreate,"%H:%M")
                        currTimeStr = datetime.datetime.now().strftime("%H:%M")
                        currTime = datetime.datetime.strptime(currTimeStr,"%H:%M")
                        delta = currTime - timeToCreate
                        deltaMinutes = abs(delta.total_seconds())
                        if(deltaMinutes < 900):
                            createImageResponse = ec2.create_image(
                                        InstanceId = instance['InstanceId'],
                                        NoReboot=(not reboot),
                                        DryRun=False,
                                        Description= instanceName + "-" + str(nowtime),
                                        Name= instanceName + "-" + str(nowtime)
                                        )
                            imageId = createImageResponse["ImageId"]
                            print imageId
                            final_tags = []
                            for tag in tags:
                                if not (tag['Key']=="Name"):
                                    final_tags.append(tag)
                                if not (tag['Key'].startswith("aws:") or tag['Value'].startswith("aws:")):
                                    final_tags.append(tag)
                            ec2.create_tags(Resources=[imageId],Tags=final_tags)
    return 'createAMI run successfully'
