# Copyright 2017 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "helper"

describe Google::Cloud::Storage::Bucket, :post_object, :lazy, :mock_storage do
  let(:bucket_name) { "bucket" }
  let(:bucket) { Google::Cloud::Storage::Bucket.new_lazy bucket_name, storage.service }

  let(:file_path) { "a/b/c/{my_file}.ext" }
  let(:file_path_encoded) { "a/b/c/%7Bmy_file%7D.ext" }
  let(:file_path_special_variable) { "a/b/c/${filename}" }

  it "uses the credentials' issuer and signing_key to generate signed post objects" do
    Time.stub :now, Time.new(2012,1,1,0,0,0, "+00:00") do
      policy = {
        expiration: Time.now.iso8601,
        conditions: [
          {bucket: bucket_name},
          {acl: "public-read"},
          {success_action_status: 201},
          [:eq, "$Content-Type", "image/jpg"]
        ]
      }

      signing_key_mock = Minitest::Mock.new

      json_policy = Base64.strict_encode64(policy.to_json).delete("\n")
      signing_key_mock.expect :sign, "native-signature", [OpenSSL::Digest::SHA256, json_policy]
      credentials.issuer = "native_client_email"
      credentials.signing_key = signing_key_mock


      signed_post = bucket.post_object file_path, policy: policy

      _(signed_post.url).must_equal Google::Cloud::Storage::GOOGLEAPIS_URL
      _(signed_post.fields[:GoogleAccessId]).must_equal "native_client_email"
      _(signed_post.fields[:signature]).must_equal Base64.strict_encode64("native-signature").delete("\n")
      _(signed_post.fields[:key]).must_equal [bucket_name, file_path_encoded].join("/")

      signing_key_mock.verify
    end
  end

  it "gives a signature even when not specifying a policy" do
    signing_key_mock = Minitest::Mock.new

    json_policy = Base64.strict_encode64("{}").delete("\n")
    signing_key_mock.expect :sign, "native-signature", [OpenSSL::Digest::SHA256, json_policy]
    credentials.issuer = "native_client_email"
    credentials.signing_key = signing_key_mock


    signed_post = bucket.post_object file_path

    _(signed_post.url).must_equal Google::Cloud::Storage::GOOGLEAPIS_URL
    _(signed_post.fields[:GoogleAccessId]).must_equal "native_client_email"
    _(signed_post.fields[:signature]).must_equal Base64.strict_encode64("native-signature").delete("\n")
    _(signed_post.fields[:key]).must_equal [bucket_name, file_path_encoded].join("/")

    signing_key_mock.verify
  end

  it "gives a signature without URI encoding the special variable path ${filename}" do
    # "You can also use the ${filename} variable if a user is providing a file name."
    # https://cloud.google.com/storage/docs/xml-api/post-object
    signing_key_mock = Minitest::Mock.new

    json_policy = Base64.strict_encode64("{}").delete("\n")
    signing_key_mock.expect :sign, "native-signature", [OpenSSL::Digest::SHA256, json_policy]
    credentials.issuer = "native_client_email"
    credentials.signing_key = signing_key_mock


    signed_post = bucket.post_object file_path_special_variable

    _(signed_post.url).must_equal Google::Cloud::Storage::GOOGLEAPIS_URL
    _(signed_post.fields[:GoogleAccessId]).must_equal "native_client_email"
    _(signed_post.fields[:signature]).must_equal Base64.strict_encode64("native-signature").delete("\n")
    _(signed_post.fields[:key]).must_equal [bucket_name, file_path_special_variable].join("/")

    signing_key_mock.verify
  end
end
