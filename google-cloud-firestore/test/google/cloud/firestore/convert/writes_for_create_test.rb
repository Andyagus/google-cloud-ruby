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

describe Google::Cloud::Firestore::Convert, :writes_for_create do
  # These tests are a sanity check on the implementation of the conversion methods.
  # These tests are testing private methods and this is generally not a great idea.
  # But these conversions are so important that it was decided to do it anyway.

  let(:document_path) { "projects/projectID/databases/(default)/documents/C/d" }
  let(:field_delete) { Google::Cloud::Firestore::FieldValue.delete }
  let(:field_server_time) { Google::Cloud::Firestore::FieldValue.server_time }

  it "basic create" do
    data = { a: 1 }

    expected_writes = [
      Google::Firestore::V1::Write.new(
        update: Google::Firestore::V1::Document.new(
          name: document_path,
          fields: {
            "a" => Google::Firestore::V1::Value.new(integer_value: 1)
          }
        ),
        current_document: Google::Firestore::V1::Precondition.new(exists: false)
      )
    ]

    actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

    _(actual_writes).must_equal expected_writes
  end

  it "complex create" do
    data = { a: [1, 2.5], b: { c: ["three", { d: true }] } }

    expected_writes = [
      Google::Firestore::V1::Write.new(
        update: Google::Firestore::V1::Document.new(
          name: document_path,
          fields: {
            "a" => Google::Firestore::V1::Value.new(array_value: Google::Firestore::V1::ArrayValue.new(values: [
              Google::Firestore::V1::Value.new(integer_value: 1),
              Google::Firestore::V1::Value.new(double_value: 2.5)
            ])),
            "b" => Google::Firestore::V1::Value.new(map_value: Google::Firestore::V1::MapValue.new(fields: {
              "c" => Google::Firestore::V1::Value.new(array_value: Google::Firestore::V1::ArrayValue.new(values: [
                Google::Firestore::V1::Value.new(string_value: "three"),
                Google::Firestore::V1::Value.new(map_value: Google::Firestore::V1::MapValue.new(fields: {
                  "d" => Google::Firestore::V1::Value.new(boolean_value: true)
                }))
              ]))
            }))
          }
        ),
        current_document: Google::Firestore::V1::Precondition.new(exists: false)
      )
    ]

    actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

    _(actual_writes).must_equal expected_writes
  end

  it "creating empty data" do
    data = {}

    expected_writes = [
      Google::Firestore::V1::Write.new(
        update: Google::Firestore::V1::Document.new(name: document_path),
        current_document: Google::Firestore::V1::Precondition.new(exists: false)
      )
    ]

    actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

    _(actual_writes).must_equal expected_writes
  end

  it "don't split on dots" do
    data = { "a.b" => { "c.d" => 1 }, "e" => 2 }

    expected_writes = [
      Google::Firestore::V1::Write.new(
        update: Google::Firestore::V1::Document.new(
          name: document_path,
          fields: {
            "a.b" => Google::Firestore::V1::Value.new(map_value: Google::Firestore::V1::MapValue.new(fields: {
              "c.d" => Google::Firestore::V1::Value.new(integer_value: 1)
            })),
            "e" => Google::Firestore::V1::Value.new(integer_value: 2)
          }
        ),
        current_document: Google::Firestore::V1::Precondition.new(exists: false)
      )
    ]

    actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

    _(actual_writes).must_equal expected_writes
  end

  it "non-alpha characters in map keys" do
    data = { "*" => { "." => 1 }, "~" => 2 }

    expected_writes = [
      Google::Firestore::V1::Write.new(
        update: Google::Firestore::V1::Document.new(
          name: document_path,
          fields: {
            "*" => Google::Firestore::V1::Value.new(map_value: Google::Firestore::V1::MapValue.new(fields: {
              "." => Google::Firestore::V1::Value.new(integer_value: 1)
            })),
            "~" => Google::Firestore::V1::Value.new(integer_value: 2)
          }
        ),
        current_document: Google::Firestore::V1::Precondition.new(exists: false)
      )
    ]

    actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

    _(actual_writes).must_equal expected_writes
  end

  describe :field_delete do
    it "DELETE cannot appear in data" do
      data = { a: 1, b: field_delete }

      error = expect do
        Google::Cloud::Firestore::Convert.writes_for_create document_path, data
      end.must_raise ArgumentError
      _(error.message).must_equal "DELETE not allowed on create"
    end
  end

  describe :field_server_time do
    it "SERVER_TIME alone" do
      data = { a: field_server_time }

      expected_writes = [
        Google::Firestore::V1::Write.new(
          transform: Google::Firestore::V1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "a",
                set_to_server_value: :REQUEST_TIME
              )
            ]
          ),
          current_document: Google::Firestore::V1::Precondition.new(exists: false)
        )
      ]

      actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

      _(actual_writes).must_equal expected_writes
    end

    it "SERVER_TIME with data" do
      data = { a: 1, b: field_server_time }

      expected_writes = [
        Google::Firestore::V1::Write.new(
          update: Google::Firestore::V1::Document.new(
            name: document_path,
            fields: {
              "a" => Google::Firestore::V1::Value.new(integer_value: 1)
            }
          ),
          current_document: Google::Firestore::V1::Precondition.new(
            exists: false)
        ),
        Google::Firestore::V1::Write.new(
          transform: Google::Firestore::V1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "b",
                set_to_server_value: :REQUEST_TIME
              )
            ]
          )
        )
      ]

      actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

      _(actual_writes).must_equal expected_writes
    end

    it "multiple SERVER_TIME fields" do
      data = { a: 1, b: field_server_time, c: { d: field_server_time } }

      expected_writes = [
        Google::Firestore::V1::Write.new(
          update: Google::Firestore::V1::Document.new(
            name: document_path,
            fields: {
              "a" => Google::Firestore::V1::Value.new(integer_value: 1)
            }
          ),
          current_document: Google::Firestore::V1::Precondition.new(exists: false)
        ),
        Google::Firestore::V1::Write.new(
          transform: Google::Firestore::V1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "b",
                set_to_server_value: :REQUEST_TIME
              ),
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "c.d",
                set_to_server_value: :REQUEST_TIME
              )
            ]
          )
        )
      ]

      actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

      _(actual_writes).must_equal expected_writes
    end

    it "nested SERVER_TIME field" do
      data = { a: 1, b: { c: field_server_time } }

      expected_writes = [
        Google::Firestore::V1::Write.new(
          update: Google::Firestore::V1::Document.new(
            name: document_path,
            fields: {
              "a" => Google::Firestore::V1::Value.new(integer_value: 1)
            }
          ),
          current_document: Google::Firestore::V1::Precondition.new(
            exists: false)
        ),
        Google::Firestore::V1::Write.new(
          transform: Google::Firestore::V1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "b.c",
                set_to_server_value: :REQUEST_TIME
              )
            ]
          )
        )
      ]

      actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

      _(actual_writes).must_equal expected_writes
    end

    it "SERVER_TIME cannot be anywhere inside an array value" do
      data = { a: [1, { b: field_server_time }] }

      error = expect do
        Google::Cloud::Firestore::Convert.writes_for_create document_path, data
      end.must_raise ArgumentError
      _(error.message).must_equal "cannot nest server_time under arrays"
    end

    it "SERVER_TIME cannot be in an array value" do
      data = { a: [1, 2, field_server_time] }

      error = expect do
        Google::Cloud::Firestore::Convert.writes_for_create document_path, data
      end.must_raise ArgumentError
      _(error.message).must_equal "cannot nest server_time under arrays"
    end
  end

  describe :field_array_union do
    let(:field_array_union) { Google::Cloud::Firestore::FieldValue.array_union 1, 2, 3 }

    it "ARRAY_UNION alone" do
      data = { a: field_array_union }

      expected_writes = [
        Google::Firestore::V1::Write.new(
          transform: Google::Firestore::V1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "a",
                append_missing_elements: Google::Firestore::V1::ArrayValue.new(
                  values: [
                    Google::Firestore::V1::Value.new(integer_value: 1),
                    Google::Firestore::V1::Value.new(integer_value: 2),
                    Google::Firestore::V1::Value.new(integer_value: 3)
                  ]
                )
              )
            ]
          ),
          current_document: Google::Firestore::V1::Precondition.new(exists: false)
        )
      ]

      actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

      _(actual_writes).must_equal expected_writes
    end

    it "ARRAY_UNION with data" do
      data = { a: 1, b: field_array_union }

      expected_writes = [
        Google::Firestore::V1::Write.new(
          update: Google::Firestore::V1::Document.new(
            name: document_path,
            fields: {
              "a" => Google::Firestore::V1::Value.new(integer_value: 1)
            }
          ),
          current_document: Google::Firestore::V1::Precondition.new(
            exists: false)
        ),
        Google::Firestore::V1::Write.new(
          transform: Google::Firestore::V1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "b",
                append_missing_elements: Google::Firestore::V1::ArrayValue.new(
                  values: [
                    Google::Firestore::V1::Value.new(integer_value: 1),
                    Google::Firestore::V1::Value.new(integer_value: 2),
                    Google::Firestore::V1::Value.new(integer_value: 3)
                  ]
                )
              )
            ]
          )
        )
      ]

      actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

      _(actual_writes).must_equal expected_writes
    end

    it "multiple ARRAY_UNION fields" do
      data = { a: 1, b: field_array_union, c: { d: field_array_union } }

      expected_writes = [
        Google::Firestore::V1::Write.new(
          update: Google::Firestore::V1::Document.new(
            name: document_path,
            fields: {
              "a" => Google::Firestore::V1::Value.new(integer_value: 1)
            }
          ),
          current_document: Google::Firestore::V1::Precondition.new(exists: false)
        ),
        Google::Firestore::V1::Write.new(
          transform: Google::Firestore::V1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "b",
                append_missing_elements: Google::Firestore::V1::ArrayValue.new(
                  values: [
                    Google::Firestore::V1::Value.new(integer_value: 1),
                    Google::Firestore::V1::Value.new(integer_value: 2),
                    Google::Firestore::V1::Value.new(integer_value: 3)
                  ]
                )
              ),
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "c.d",
                append_missing_elements: Google::Firestore::V1::ArrayValue.new(
                  values: [
                    Google::Firestore::V1::Value.new(integer_value: 1),
                    Google::Firestore::V1::Value.new(integer_value: 2),
                    Google::Firestore::V1::Value.new(integer_value: 3)
                  ]
                )
              )
            ]
          )
        )
      ]

      actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

      _(actual_writes).must_equal expected_writes
    end

    it "nested ARRAY_UNION field" do
      data = { a: 1, b: { c: field_array_union } }

      expected_writes = [
        Google::Firestore::V1::Write.new(
          update: Google::Firestore::V1::Document.new(
            name: document_path,
            fields: {
              "a" => Google::Firestore::V1::Value.new(integer_value: 1)
            }
          ),
          current_document: Google::Firestore::V1::Precondition.new(
            exists: false)
        ),
        Google::Firestore::V1::Write.new(
          transform: Google::Firestore::V1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "b.c",
                append_missing_elements: Google::Firestore::V1::ArrayValue.new(
                  values: [
                    Google::Firestore::V1::Value.new(integer_value: 1),
                    Google::Firestore::V1::Value.new(integer_value: 2),
                    Google::Firestore::V1::Value.new(integer_value: 3)
                  ]
                )
              )
            ]
          )
        )
      ]

      actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

      _(actual_writes).must_equal expected_writes
    end

    it "ARRAY_UNION cannot be anywhere inside an array value" do
      data = { a: [1, { b: field_array_union }] }

      error = expect do
        Google::Cloud::Firestore::Convert.writes_for_create document_path, data
      end.must_raise ArgumentError
      _(error.message).must_equal "cannot nest array_union under arrays"
    end

    it "ARRAY_UNION cannot be in an array value" do
      data = { a: [1, 2, field_array_union] }

      error = expect do
        Google::Cloud::Firestore::Convert.writes_for_create document_path, data
      end.must_raise ArgumentError
      _(error.message).must_equal "cannot nest array_union under arrays"
    end
  end

  describe :field_array_delete do
    let(:field_array_delete) { Google::Cloud::Firestore::FieldValue.array_delete 7, 8, 9 }

    it "ARRAY_DELETE alone" do
      data = { a: field_array_delete }

      expected_writes = [
        Google::Firestore::V1::Write.new(
          transform: Google::Firestore::V1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "a",
                remove_all_from_array: Google::Firestore::V1::ArrayValue.new(
                  values: [
                    Google::Firestore::V1::Value.new(integer_value: 7),
                    Google::Firestore::V1::Value.new(integer_value: 8),
                    Google::Firestore::V1::Value.new(integer_value: 9)
                  ]
                )
              )
            ]
          ),
          current_document: Google::Firestore::V1::Precondition.new(exists: false)
        )
      ]

      actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

      _(actual_writes).must_equal expected_writes
    end

    it "ARRAY_DELETE with data" do
      data = { a: 1, b: field_array_delete }

      expected_writes = [
        Google::Firestore::V1::Write.new(
          update: Google::Firestore::V1::Document.new(
            name: document_path,
            fields: {
              "a" => Google::Firestore::V1::Value.new(integer_value: 1)
            }
          ),
          current_document: Google::Firestore::V1::Precondition.new(
            exists: false)
        ),
        Google::Firestore::V1::Write.new(
          transform: Google::Firestore::V1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "b",
                remove_all_from_array: Google::Firestore::V1::ArrayValue.new(
                  values: [
                    Google::Firestore::V1::Value.new(integer_value: 7),
                    Google::Firestore::V1::Value.new(integer_value: 8),
                    Google::Firestore::V1::Value.new(integer_value: 9)
                  ]
                )
              )
            ]
          )
        )
      ]

      actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

      _(actual_writes).must_equal expected_writes
    end

    it "multiple ARRAY_DELETE fields" do
      data = { a: 1, b: field_array_delete, c: { d: field_array_delete } }

      expected_writes = [
        Google::Firestore::V1::Write.new(
          update: Google::Firestore::V1::Document.new(
            name: document_path,
            fields: {
              "a" => Google::Firestore::V1::Value.new(integer_value: 1)
            }
          ),
          current_document: Google::Firestore::V1::Precondition.new(exists: false)
        ),
        Google::Firestore::V1::Write.new(
          transform: Google::Firestore::V1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "b",
                remove_all_from_array: Google::Firestore::V1::ArrayValue.new(
                  values: [
                    Google::Firestore::V1::Value.new(integer_value: 7),
                    Google::Firestore::V1::Value.new(integer_value: 8),
                    Google::Firestore::V1::Value.new(integer_value: 9)
                  ]
                )
              ),
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "c.d",
                remove_all_from_array: Google::Firestore::V1::ArrayValue.new(
                  values: [
                    Google::Firestore::V1::Value.new(integer_value: 7),
                    Google::Firestore::V1::Value.new(integer_value: 8),
                    Google::Firestore::V1::Value.new(integer_value: 9)
                  ]
                )
              )
            ]
          )
        )
      ]

      actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

      _(actual_writes).must_equal expected_writes
    end

    it "nested ARRAY_DELETE field" do
      data = { a: 1, b: { c: field_array_delete } }

      expected_writes = [
        Google::Firestore::V1::Write.new(
          update: Google::Firestore::V1::Document.new(
            name: document_path,
            fields: {
              "a" => Google::Firestore::V1::Value.new(integer_value: 1)
            }
          ),
          current_document: Google::Firestore::V1::Precondition.new(
            exists: false)
        ),
        Google::Firestore::V1::Write.new(
          transform: Google::Firestore::V1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "b.c",
                remove_all_from_array: Google::Firestore::V1::ArrayValue.new(
                  values: [
                    Google::Firestore::V1::Value.new(integer_value: 7),
                    Google::Firestore::V1::Value.new(integer_value: 8),
                    Google::Firestore::V1::Value.new(integer_value: 9)
                  ]
                )
              )
            ]
          )
        )
      ]

      actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

      _(actual_writes).must_equal expected_writes
    end

    it "ARRAY_DELETE cannot be anywhere inside an array value" do
      data = { a: [1, { b: field_array_delete }] }

      error = expect do
        Google::Cloud::Firestore::Convert.writes_for_create document_path, data
      end.must_raise ArgumentError
      _(error.message).must_equal "cannot nest array_delete under arrays"
    end

    it "ARRAY_DELETE cannot be in an array value" do
      data = { a: [1, 2, field_array_delete] }

      error = expect do
        Google::Cloud::Firestore::Convert.writes_for_create document_path, data
      end.must_raise ArgumentError
      _(error.message).must_equal "cannot nest array_delete under arrays"
    end
  end

  describe :field_increment do
    let(:field_increment) { Google::Cloud::Firestore::FieldValue.increment 1 }

    it "INCREMENT alone" do
      data = { a: field_increment }

      expected_writes = [
        Google::Firestore::V1::Write.new(
          transform: Google::Firestore::V1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "a",
                increment: Google::Firestore::V1::Value.new(integer_value: 1)
              )
            ]
          ),
          current_document: Google::Firestore::V1::Precondition.new(exists: false)
        )
      ]

      actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

      _(actual_writes).must_equal expected_writes
    end

    it "INCREMENT with data" do
      data = { a: 1, b: field_increment }

      expected_writes = [
        Google::Firestore::V1::Write.new(
          update: Google::Firestore::V1::Document.new(
            name: document_path,
            fields: {
              "a" => Google::Firestore::V1::Value.new(integer_value: 1)
            }
          ),
          current_document: Google::Firestore::V1::Precondition.new(
            exists: false)
        ),
        Google::Firestore::V1::Write.new(
          transform: Google::Firestore::V1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "b",
                increment: Google::Firestore::V1::Value.new(integer_value: 1)
              )
            ]
          )
        )
      ]

      actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

      _(actual_writes).must_equal expected_writes
    end

    it "multiple INCREMENT fields" do
      data = { a: 1, b: field_increment, c: { d: field_increment } }

      expected_writes = [
        Google::Firestore::V1::Write.new(
          update: Google::Firestore::V1::Document.new(
            name: document_path,
            fields: {
              "a" => Google::Firestore::V1::Value.new(integer_value: 1)
            }
          ),
          current_document: Google::Firestore::V1::Precondition.new(exists: false)
        ),
        Google::Firestore::V1::Write.new(
          transform: Google::Firestore::V1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "b",
                increment: Google::Firestore::V1::Value.new(integer_value: 1)
              ),
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "c.d",
                increment: Google::Firestore::V1::Value.new(integer_value: 1)
              )
            ]
          )
        )
      ]

      actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

      _(actual_writes).must_equal expected_writes
    end

    it "nested INCREMENT field" do
      data = { a: 1, b: { c: field_increment } }

      expected_writes = [
        Google::Firestore::V1::Write.new(
          update: Google::Firestore::V1::Document.new(
            name: document_path,
            fields: {
              "a" => Google::Firestore::V1::Value.new(integer_value: 1)
            }
          ),
          current_document: Google::Firestore::V1::Precondition.new(
            exists: false)
        ),
        Google::Firestore::V1::Write.new(
          transform: Google::Firestore::V1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "b.c",
                increment: Google::Firestore::V1::Value.new(integer_value: 1)
              )
            ]
          )
        )
      ]

      actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

      _(actual_writes).must_equal expected_writes
    end

    it "INCREMENT cannot be anywhere inside an array value" do
      data = { a: [1, { b: field_increment }] }

      error = expect do
        Google::Cloud::Firestore::Convert.writes_for_create document_path, data
      end.must_raise ArgumentError
      _(error.message).must_equal "cannot nest increment under arrays"
    end

    it "INCREMENT cannot be in an array value" do
      data = { a: [1, 2, field_increment] }

      error = expect do
        Google::Cloud::Firestore::Convert.writes_for_create document_path, data
      end.must_raise ArgumentError
      _(error.message).must_equal "cannot nest increment under arrays"
    end
  end

  describe :field_maximum do
    let(:field_maximum) { Google::Cloud::Firestore::FieldValue.maximum 1 }

    it "MAXIMUM alone" do
      data = { a: field_maximum }

      expected_writes = [
        Google::Firestore::V1::Write.new(
          transform: Google::Firestore::V1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "a",
                maximum: Google::Firestore::V1::Value.new(integer_value: 1)
              )
            ]
          ),
          current_document: Google::Firestore::V1::Precondition.new(exists: false)
        )
      ]

      actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

      _(actual_writes).must_equal expected_writes
    end

    it "MAXIMUM with data" do
      data = { a: 1, b: field_maximum }

      expected_writes = [
        Google::Firestore::V1::Write.new(
          update: Google::Firestore::V1::Document.new(
            name: document_path,
            fields: {
              "a" => Google::Firestore::V1::Value.new(integer_value: 1)
            }
          ),
          current_document: Google::Firestore::V1::Precondition.new(
            exists: false)
        ),
        Google::Firestore::V1::Write.new(
          transform: Google::Firestore::V1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "b",
                maximum: Google::Firestore::V1::Value.new(integer_value: 1)
              )
            ]
          )
        )
      ]

      actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

      _(actual_writes).must_equal expected_writes
    end

    it "multiple MAXIMUM fields" do
      data = { a: 1, b: field_maximum, c: { d: field_maximum } }

      expected_writes = [
        Google::Firestore::V1::Write.new(
          update: Google::Firestore::V1::Document.new(
            name: document_path,
            fields: {
              "a" => Google::Firestore::V1::Value.new(integer_value: 1)
            }
          ),
          current_document: Google::Firestore::V1::Precondition.new(exists: false)
        ),
        Google::Firestore::V1::Write.new(
          transform: Google::Firestore::V1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "b",
                maximum: Google::Firestore::V1::Value.new(integer_value: 1)
              ),
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "c.d",
                maximum: Google::Firestore::V1::Value.new(integer_value: 1)
              )
            ]
          )
        )
      ]

      actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

      _(actual_writes).must_equal expected_writes
    end

    it "nested MAXIMUM field" do
      data = { a: 1, b: { c: field_maximum } }

      expected_writes = [
        Google::Firestore::V1::Write.new(
          update: Google::Firestore::V1::Document.new(
            name: document_path,
            fields: {
              "a" => Google::Firestore::V1::Value.new(integer_value: 1)
            }
          ),
          current_document: Google::Firestore::V1::Precondition.new(
            exists: false)
        ),
        Google::Firestore::V1::Write.new(
          transform: Google::Firestore::V1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "b.c",
                maximum: Google::Firestore::V1::Value.new(integer_value: 1)
              )
            ]
          )
        )
      ]

      actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

      _(actual_writes).must_equal expected_writes
    end

    it "MAXIMUM cannot be anywhere inside an array value" do
      data = { a: [1, { b: field_maximum }] }

      error = expect do
        Google::Cloud::Firestore::Convert.writes_for_create document_path, data
      end.must_raise ArgumentError
      _(error.message).must_equal "cannot nest maximum under arrays"
    end

    it "MAXIMUM cannot be in an array value" do
      data = { a: [1, 2, field_maximum] }

      error = expect do
        Google::Cloud::Firestore::Convert.writes_for_create document_path, data
      end.must_raise ArgumentError
      _(error.message).must_equal "cannot nest maximum under arrays"
    end
  end

  describe :field_minimum do
    let(:field_minimum) { Google::Cloud::Firestore::FieldValue.minimum 1 }

    it "MINIMUM alone" do
      data = { a: field_minimum }

      expected_writes = [
        Google::Firestore::V1::Write.new(
          transform: Google::Firestore::V1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "a",
                minimum: Google::Firestore::V1::Value.new(integer_value: 1)
              )
            ]
          ),
          current_document: Google::Firestore::V1::Precondition.new(exists: false)
        )
      ]

      actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

      _(actual_writes).must_equal expected_writes
    end

    it "MINIMUM with data" do
      data = { a: 1, b: field_minimum }

      expected_writes = [
        Google::Firestore::V1::Write.new(
          update: Google::Firestore::V1::Document.new(
            name: document_path,
            fields: {
              "a" => Google::Firestore::V1::Value.new(integer_value: 1)
            }
          ),
          current_document: Google::Firestore::V1::Precondition.new(
            exists: false)
        ),
        Google::Firestore::V1::Write.new(
          transform: Google::Firestore::V1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "b",
                minimum: Google::Firestore::V1::Value.new(integer_value: 1)
              )
            ]
          )
        )
      ]

      actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

      _(actual_writes).must_equal expected_writes
    end

    it "multiple MINIMUM fields" do
      data = { a: 1, b: field_minimum, c: { d: field_minimum } }

      expected_writes = [
        Google::Firestore::V1::Write.new(
          update: Google::Firestore::V1::Document.new(
            name: document_path,
            fields: {
              "a" => Google::Firestore::V1::Value.new(integer_value: 1)
            }
          ),
          current_document: Google::Firestore::V1::Precondition.new(exists: false)
        ),
        Google::Firestore::V1::Write.new(
          transform: Google::Firestore::V1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "b",
                minimum: Google::Firestore::V1::Value.new(integer_value: 1)
              ),
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "c.d",
                minimum: Google::Firestore::V1::Value.new(integer_value: 1)
              )
            ]
          )
        )
      ]

      actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

      _(actual_writes).must_equal expected_writes
    end

    it "nested MINIMUM field" do
      data = { a: 1, b: { c: field_minimum } }

      expected_writes = [
        Google::Firestore::V1::Write.new(
          update: Google::Firestore::V1::Document.new(
            name: document_path,
            fields: {
              "a" => Google::Firestore::V1::Value.new(integer_value: 1)
            }
          ),
          current_document: Google::Firestore::V1::Precondition.new(
            exists: false)
        ),
        Google::Firestore::V1::Write.new(
          transform: Google::Firestore::V1::DocumentTransform.new(
            document: "projects/projectID/databases/(default)/documents/C/d",
            field_transforms: [
              Google::Firestore::V1::DocumentTransform::FieldTransform.new(
                field_path: "b.c",
                minimum: Google::Firestore::V1::Value.new(integer_value: 1)
              )
            ]
          )
        )
      ]

      actual_writes = Google::Cloud::Firestore::Convert.writes_for_create document_path, data

      _(actual_writes).must_equal expected_writes
    end

    it "MINIMUM cannot be anywhere inside an array value" do
      data = { a: [1, { b: field_minimum }] }

      error = expect do
        Google::Cloud::Firestore::Convert.writes_for_create document_path, data
      end.must_raise ArgumentError
      _(error.message).must_equal "cannot nest minimum under arrays"
    end

    it "MINIMUM cannot be in an array value" do
      data = { a: [1, 2, field_minimum] }

      error = expect do
        Google::Cloud::Firestore::Convert.writes_for_create document_path, data
      end.must_raise ArgumentError
      _(error.message).must_equal "cannot nest minimum under arrays"
    end
  end
end
