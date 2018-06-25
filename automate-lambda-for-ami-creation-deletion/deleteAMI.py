def lambda_handler(event, context):
    import boto3
    import datetime
    import time

    client = boto3.client('ec2')
    regions = [region['RegionName'] for region in client.describe_regions()['Regions']]
    for regionnaire in regions:
        print regionnaire
        ec2 = boto3.client("ec2", region_name=regionnaire)
        response = ec2.describe_images(Owners=['self'],DryRun=False)
        for i in range(len(response['Images'])):
            ami = False
            retention = 7
            creationDate = response["Images"][i]["CreationDate"][:10]
            AMIdate = datetime.datetime.strptime(creationDate, '%Y-%m-%d')
            timeStampNow = datetime.datetime.now()
            if response['Images'][i].get("Tags",None) != None :
                tags = response['Images'][i]['Tags']
                for tag in tags:
                    if(tag["Key"] == "AMIBackup" and tag["Value"] == "Yes"):
                        ami = True
                    if(tag["Key"] == "Retention"):
                        retention = tag["Value"]
                if(ami==True):
                    if (timeStampNow - AMIdate).days >= int(retention):
                        print str("Deleting AMI: ") + response["Images"][i]["ImageId"]
                        deregisterImageResponse = client.deregister_image(ImageId=response['Images'][i]['ImageId'])
                        time.sleep(1)
                        for k in range(len(response['Images'][i]['BlockDeviceMappings'])):
                            deleteSnapshotResponse = client.delete_snapshot(SnapshotId=response['Images'][i]['BlockDeviceMappings'][k]['Ebs']['SnapshotId'])