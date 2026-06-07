// Developer-facing S3 bucket claim. The developer asks for a bucket; this resolves
// to the XS3Bucket composite (platform/crossplane/s3/) — a backend-swappable claim
// (Crossplane today, ACK later) that doesn't change between backends.
"bucket": {
	type:        "component"
	description: "Claim an S3 bucket, resolved by a Crossplane Composition."
	attributes: {
		workload: definition: {
			apiVersion: "platform.example.com/v1alpha1"
			kind:       "XS3Bucket"
		}
		status: {
			healthPolicy: #"""
				isHealth: bool | *false
				if context.output.status != _|_ {
					if context.output.status.conditions != _|_ {
						for c in context.output.status.conditions {
							if c.type == "Ready" && c.status == "True" {
								isHealth: true
							}
						}
					}
				}
				"""#
			customStatus: #"""
				message: string | *"Provisioning S3 bucket..."
				if context.output.status != _|_ {
					if context.output.status.bucketArn != _|_ {
						message: "Bucket ARN: " + context.output.status.bucketArn
					}
					if context.output.status.bucketName != _|_ {
						message: message + " | Name: " + context.output.status.bucketName
					}
				}
				"""#
		}
	}
}

template: {
	output: {
		apiVersion: "platform.example.com/v1alpha1"
		kind:       "XS3Bucket"
		metadata: {
			name:      parameter.name
			namespace: context.namespace
		}
		spec: {
			name:       parameter.name
			region:     parameter.region
			versioning: parameter.versioning
			crossplane: {
				compositionRef: {
					name: "s3-bucket.platform.example.com"
				}
			}
		}
	}

	parameter: {
		// +usage=Name of the S3 bucket
		name: string

		// +usage=AWS region
		region: *"us-west-2" | string

		// +usage=Enable versioning on the bucket
		versioning: *false | bool
	}
}
