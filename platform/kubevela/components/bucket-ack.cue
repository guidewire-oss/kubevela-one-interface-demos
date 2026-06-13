// Developer-facing S3 bucket claim — ACK backing (Track 2).
//
// This is the SAME `bucket` component as components/bucket.cue, but resolved by the
// AWS Controllers for Kubernetes (ACK) S3 controller instead of a Crossplane
// Composition. The developer-facing contract is byte-for-byte identical: same
// component name (`bucket`) and same parameters (name / region / versioning), so the
// demo Application (demos/<demo>/kubevela/product-catalog.yaml) needs NO change to
// switch tracks. Apply exactly ONE of bucket.cue / bucket-ack.cue — both register a
// ComponentDefinition named `bucket`; whichever is installed backs the claim.
//
// Where Crossplane fans a single XS3Bucket claim out into three managed resources
// (Bucket + BucketVersioning + BucketPublicAccessBlock) via a Composition, ACK has no
// composition layer: the one `s3.services.k8s.aws/v1alpha1` Bucket carries versioning,
// the public-access block, and tagging inline as spec fields. So this component emits
// that single resource and folds the same capabilities into it.
"bucket": {
	type:        "component"
	description: "Claim an S3 bucket, resolved by the ACK S3 controller."
	attributes: {
		workload: definition: {
			apiVersion: "s3.services.k8s.aws/v1alpha1"
			kind:       "Bucket"
		}
		status: {
			// ACK marks a resource ready with a condition of type `ACK.ResourceSynced`
			// (status True) — not `Ready` as Crossplane does.
			healthPolicy: #"""
				isHealth: bool | *false
				if context.output.status != _|_ {
					if context.output.status.conditions != _|_ {
						for c in context.output.status.conditions {
							if c.type == "ACK.ResourceSynced" && c.status == "True" {
								isHealth: true
							}
						}
					}
				}
				"""#
			// ACK surfaces the bucket ARN at status.ackResourceMetadata.arn.
			customStatus: #"""
				message: string | *"Provisioning S3 bucket (ACK)..."
				if context.output.status != _|_ {
					if context.output.status.ackResourceMetadata != _|_ {
						if context.output.status.ackResourceMetadata.arn != _|_ {
							message: "Bucket ARN: " + context.output.status.ackResourceMetadata.arn
						}
					}
				}
				"""#
		}
	}
}

template: {
	output: {
		apiVersion: "s3.services.k8s.aws/v1alpha1"
		kind:       "Bucket"
		metadata: {
			// Append the namespace so the SAME claim across dev/staging/prod yields
			// distinct, globally-unique S3 bucket names instead of colliding.
			name:      "\(parameter.name)-\(context.namespace)"
			namespace: context.namespace
			// Pin the regional S3 endpoint the controller talks to for THIS bucket,
			// independent of the controller's default region.
			annotations: "services.k8s.aws/region": parameter.region
		}
		spec: {
			// S3 bucket name = claim name + namespace (globally unique per env) —
			// matches the metadata name above and the Crossplane/KCC tracks.
			name: "\(parameter.name)-\(context.namespace)"

			// S3 only accepts (and requires) a LocationConstraint for regions other
			// than us-east-1; for us-east-1 it must be omitted.
			if parameter.region != "us-east-1" {
				createBucketConfiguration: locationConstraint: parameter.region
			}

			// Versioning: map the bool claim to S3's Enabled/Suspended, as the
			// Crossplane Composition does.
			versioning: {
				if parameter.versioning {
					status: "Enabled"
				}
				if !parameter.versioning {
					status: "Suspended"
				}
			}

			// Block all public access — parity with the Composition's
			// BucketPublicAccessBlock resource.
			publicAccessBlock: {
				blockPublicACLs:       true
				blockPublicPolicy:     true
				ignorePublicACLs:      true
				restrictPublicBuckets: true
			}
		}
	}

	// IDENTICAL to components/bucket.cue — the developer contract must not differ
	// between the Crossplane and ACK backings.
	parameter: {
		// +usage=Name of the S3 bucket
		name: string

		// +usage=AWS region
		region: *"us-west-2" | string

		// +usage=Enable versioning on the bucket
		versioning: *false | bool
	}
}
