// Developer-facing bucket claim — KCC backing (Track 3, GCP).
//
// This is the SAME `bucket` component as components/bucket.cue (Crossplane) and
// bucket-ack.cue (ACK), but resolved by Google Config Connector (KCC) into a GCS
// StorageBucket instead of an AWS S3 bucket. The developer-facing contract is
// byte-for-byte identical: same component name (`bucket`) and same parameters
// (name / region / versioning), so the demo Application
// (demos/<demo>/kubevela/product-catalog.yaml) needs NO change to switch CLOUDS.
// Apply exactly ONE of bucket.cue / bucket-ack.cue / bucket-kcc.cue — all three
// register a ComponentDefinition named `bucket`; whichever is installed backs the
// claim. This track is the strongest "one interface" beat: the same claim crosses
// not just backends but clouds (AWS → GCP).
//
// Like ACK (and unlike Crossplane, which fans a claim out into three managed
// resources via a Composition), KCC has no composition layer: a single
// storage.cnrm.cloud.google.com StorageBucket carries versioning and public-access
// settings inline, so this component emits that one resource directly.
//
// Project: the GCP project is set via the cnrm.cloud.google.com/project-id
// annotation on the StorageBucket, driven by the OPTIONAL projectName parameter
// (default "kubecon-in-2026"). Because it has a default, the shared developer
// Application YAML still applies unchanged across all three tracks — the
// identical-claim contract holds; the AWS backings just have no such field.
"bucket": {
	type:        "component"
	description: "Claim a bucket, resolved by Google Config Connector into a GCS bucket."
	attributes: {
		workload: definition: {
			apiVersion: "storage.cnrm.cloud.google.com/v1beta1"
			kind:       "StorageBucket"
		}
		status: {
			// KCC marks a resource ready with a condition of type `Ready` (status True).
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
			// KCC surfaces the bucket's URL at status.url.
			customStatus: #"""
				message: string | *"Provisioning GCS bucket (KCC)..."
				if context.output.status != _|_ {
					if context.output.status.url != _|_ {
						message: "Bucket URL: " + context.output.status.url
					}
				}
				"""#
		}
	}
}

template: {
	// AWS region names (the claim's default is us-west-2) are NOT valid GCS
	// locations. Map the common ones to their nearest GCP region so the SAME
	// developer YAML provisions on GCP; anything unmapped falls back to us-central1.
	// (ap-south-1 → asia-south1 is Mumbai — fitting for KubeCon India.)
	_awsToGcpLocation: {
		"us-east-1":      "us-east1"
		"us-east-2":      "us-east1"
		"us-west-1":      "us-west2"
		"us-west-2":      "us-west1"
		"ca-central-1":   "northamerica-northeast1"
		"eu-west-1":      "europe-west1"
		"eu-west-2":      "europe-west2"
		"eu-central-1":   "europe-west3"
		"ap-south-1":     "asia-south1"
		"ap-southeast-1": "asia-southeast1"
		"ap-southeast-2": "australia-southeast1"
		"ap-northeast-1": "asia-northeast1"
		"sa-east-1":      "southamerica-east1"
	}

	output: {
		apiVersion: "storage.cnrm.cloud.google.com/v1beta1"
		kind:       "StorageBucket"
		metadata: {
			// metadata.name doubles as the GCS bucket name. Append the namespace so the
			// SAME claim across dev/staging/prod yields distinct, globally-unique GCS
			// bucket names (e.g. product-catalog-images-dev) instead of colliding on one
			// global name.
			name:      "\(parameter.name)-\(context.namespace)"
			namespace: context.namespace
			// The GCP project this bucket is created in, driven by the projectName
			// parameter (default kubecon-in-2026). Set here per-resource, so no
			// namespace-level project annotation is required.
			annotations: "cnrm.cloud.google.com/project-id": parameter.projectName
		}
		spec: {
			// region → location, translated AWS→GCP (see _awsToGcpLocation above).
			location: [
				if _awsToGcpLocation[parameter.region] != _|_ {_awsToGcpLocation[parameter.region]},
				"us-central1",
			][0]

			// Versioning: GCS takes a plain bool — no Enabled/Suspended string mapping
			// (contrast the S3 tracks), so the claim's bool passes straight through.
			versioning: enabled: parameter.versioning

			// Block all public access — parity with the Crossplane
			// BucketPublicAccessBlock and the ACK publicAccessBlock (all-true). On GCS
			// this is two settings.
			uniformBucketLevelAccess: true
			publicAccessPrevention:   "enforced"
		}
	}

	// The name/region/versioning trio is IDENTICAL to components/bucket.cue and
	// bucket-ack.cue. projectName is a KCC-only OPTIONAL extra: it has a default,
	// so the shared developer YAML still applies unchanged across all three tracks
	// (the AWS backings simply have no such field to set).
	parameter: {
		// +usage=Name of the S3 bucket
		name: string

		// +usage=AWS region
		region: *"us-west-2" | string

		// +usage=Enable versioning on the bucket
		versioning: *false | bool

		// +usage=GCP project to create the bucket in (KCC only)
		projectName: *"kubecon-in-2026" | string
	}
}
