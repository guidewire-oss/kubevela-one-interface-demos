// Enable S3 bucket versioning. Applies to the direct `s3-bucket` component
// (patches its underlying AWS Bucket); the `bucket` claim handles versioning via
// its own `versioning` parameter instead.
"s3-versioning": {
	annotations: {}
	labels: {}
	attributes: {
		appliesToWorkloads: ["s3-bucket"]
	}
	description: "Enable versioning for an S3 bucket"
	type:        "trait"
}

template: {
	patch: {
		spec: forProvider: versioning: [{
			enabled: parameter.enabled
		}]
	}

	parameter: {
		// +usage=Enable or disable versioning
		enabled: bool | *true
	}
}
