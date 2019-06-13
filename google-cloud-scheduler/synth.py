# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""This script is used to synthesize generated parts of this library."""

import synthtool as s
import synthtool.gcp as gcp
import synthtool.languages.ruby as ruby
import logging
# from textwrap import dedent
# from os import listdir
# from os.path import isfile, join
from subprocess import call, check_output

logging.basicConfig(level=logging.DEBUG)

gapic = gcp.GAPICGenerator()

v1beta1_library = gapic.ruby_library(
    'scheduler',
    'v1beta1',
    config_path='artman_cloudscheduler_v1beta1.yaml',
    artman_output_name='google-cloud-ruby/google-cloud-cloudscheduler',
)

s.copy(v1beta1_library / 'lib/google/cloud/scheduler/v1beta1')
s.copy(v1beta1_library / 'lib/google/cloud/scheduler/v1beta1.rb')
s.copy(v1beta1_library / 'test/google/cloud/scheduler/v1beta1')

# Copy common templates
templates = gcp.CommonTemplates().ruby_library()
s.copy(templates)


v1_library = gapic.ruby_library(
    'scheduler',
    'v1',
    config_path='artman_cloudscheduler_v1.yaml',
    artman_output_name='google-cloud-ruby/google-cloud-cloudscheduler',
)

s.copy(v1_library / 'lib/google/cloud/scheduler/v1')
s.copy(v1_library / 'lib/google/cloud/scheduler/v1.rb')
s.copy(v1_library / 'lib/google/cloud/scheduler.rb')
s.copy(v1_library / 'test/google/cloud/scheduler/v1')
s.copy(v1_library / 'README.md')
s.copy(v1_library / 'LICENSE')
s.copy(v1_library / '.gitignore')
s.copy(v1_library / '.yardopts')
s.copy(v1_library / 'google-cloud-scheduler.gemspec', merge=ruby.merge_gemspec)

s.replace(
    'google-cloud-scheduler.gemspec',
    'gem.add_development_dependency "rubocop".*$',
    'gem.add_development_dependency "rubocop", "~> 0.64.0"'
)

# https://github.com/googleapis/gapic-generator/issues/2279
s.replace(
    'lib/**/*.rb',
    '\\A(((#[^\n]*)?\n)*# (Copyright \\d+|Generated by the protocol buffer compiler)[^\n]+\n(#[^\n]*\n)*\n)([^\n])',
    '\\1\n\\6')

# https://github.com/googleapis/gapic-generator/issues/2323
s.replace(
    ['lib/**/*.rb', 'README.md'],
    'https://github\\.com/GoogleCloudPlatform/google-cloud-ruby',
    'https://github.com/googleapis/google-cloud-ruby'
)
s.replace(
    ['lib/**/*.rb', 'README.md'],
    'https://googlecloudplatform\\.github\\.io/google-cloud-ruby',
    'https://googleapis.github.io/google-cloud-ruby'
)

# https://github.com/googleapis/gapic-generator/issues/2243
s.replace(
    'lib/google/cloud/scheduler/**/*_client.rb',
    '(\n\\s+class \\w+Client\n)(\\s+)(attr_reader :\\w+_stub)',
    '\\1\\2# @private\n\\2\\3')

for version in ['v1beta1', 'v1']:
    # Require the helpers file
    s.replace(
        f'lib/google/cloud/scheduler/{version}.rb',
        f'require "google/cloud/scheduler/{version}/cloud_scheduler_client"',
        '\n'.join([
            f'require "google/cloud/scheduler/{version}/cloud_scheduler_client"',
            f'require "google/cloud/scheduler/{version}/helpers"'
        ])
    )

s.replace(
    'google-cloud-scheduler.gemspec',
    'gem.add_dependency "google-gax", "~> 1.3"',
    "\n".join([
        'gem.add_dependency "google-gax", "~> 1.3"',
        '  gem.add_dependency "googleapis-common-protos", ">= 1.3.9", "< 2.0"'
    ])
)

s.replace(
    'google-cloud-scheduler.gemspec',
    '"README.md", "LICENSE"',
    '"README.md", "AUTHENTICATION.md", "LICENSE"'
)
s.replace(
    '.yardopts',
    'README.md\n',
    'README.md\nAUTHENTICATION.md\nLICENSE\n'
)

# https://github.com/googleapis/google-cloud-ruby/issues/3058
s.replace(
    'google-cloud-scheduler.gemspec',
    '\nGem::Specification.new do',
    'require File.expand_path("../lib/google/cloud/scheduler/version", __FILE__)\n\nGem::Specification.new do'
)
s.replace(
    'google-cloud-scheduler.gemspec',
    '(gem.version\s+=\s+).\d+.\d+.\d.*$',
    '\\1Google::Cloud::Scheduler::VERSION'
)
for version in ['v1', 'v1beta1']:
    s.replace(
        f'lib/google/cloud/scheduler/{version}/*_client.rb',
        f'(require \".*credentials\"\n)\n',
        f'\\1require "google/cloud/scheduler/version"\n\n'
    )
    s.replace(
        f'lib/google/cloud/scheduler/{version}/*_client.rb',
        'Gem.loaded_specs\[.*\]\.version\.version',
        'Google::Cloud::Scheduler::VERSION'
    )

# Generate the helper methods
call('bundle update && bundle exec rake generate_partials', shell=True)

# Exception tests have to check for both custom errors and retry wrapper errors
for version in ['v1', 'v1beta1']:
    s.replace(
        f'test/google/cloud/scheduler/{version}/*_client_test.rb',
        'err = assert_raises Google::Gax::GaxError do',
        f'err = assert_raises Google::Gax::GaxError, CustomTestError_{version} do'
    )