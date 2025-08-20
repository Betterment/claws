require "forwardable"
require "claws/cli/yaml_with_lines"

class Workflow
  extend Forwardable

  attr_accessor :data, :on, :jobs, :name, :meta, :permissions

  def_delegators :@workflow, :get_line, :include?, :keys

  def initialize(raw_yaml)
    @workflow = YAMLWithLines.load(raw_yaml)

    # enriched metadata about the workflow as a whole
    @meta = {}

    normalize_dashes(@workflow)
    extract_normalized_on(@workflow)
    extract_normalized_jobs(@workflow)
    extract_normalized_name(@workflow)
    extract_permissions(@workflow)

    @raw_yaml = raw_yaml
  end

  def self.load(blob)
    Workflow.new(blob)
  end

  def line
    @workflow.line
  end

  def [](key)
    return @on if key.to_s == "on"
    return @jobs if key.to_s == "jobs"
    return @name if key.to_s == "name"
  end

  def get_snippet(line, context: 3)
    buffer = ""
    (([0, line - context].max)..(line + context)).each do |i|
      next if @raw_yaml.lines[i].nil?

      buffer += if i + 1 == line
                  ">>> #{@raw_yaml.lines[i]}"
                else
                  @raw_yaml.lines[i]
                end
    end

    buffer
  end

  def ignores
    ignores = {}

    @raw_yaml.lines.each_with_index do |line, i|
      i += 1 # line numbers are one indexed

      matches = line.match(/^\s*#.*ignore: (.*)/)
      next if matches.nil?

      matches = matches[1].split(",").map(&:strip)
      ignores[i] = matches
    end

    ignores
  end

  private

  def normalize_dashes(input)
    return input unless input.is_a? Hash

    input.clone.each do |old_key, v|
      new_key = old_key.to_s.gsub(/-/, "_")

      if old_key != new_key
        copy_key_with_line(input, old_key, new_key)
        input.delete(old_key)
      end

      normalize_dashes(v)
    end

    input
  end

  def extract_permissions(input)
    @permissions = input["permissions"]
    @meta["permissions"] = normalize_permissions(input["permissions"])
  end

  def normalize_permissions(input) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    permissions = {
      read: [],
      write: [],
      none: [],
      read_all: false,
      write_all: false
    }

    return permissions if input.nil?

    if input.is_a? String
      permissions[:read_all] = true if input == "read-all"
      permissions[:write_all] = true if input == "write-all"

      return permissions
    end

    return unless input.is_a? Hash

    input.each do |k, v|
      permissions[:read] << k if v == "read"
      permissions[:write] << k if v == "write"
      permissions[:none] << k if v == "none"
    end

    permissions
  end

  def extract_normalized_on(workflow)
    if workflow["on"].is_a? String
      line_number = workflow.keys.first { |k| k == "on" }.line
      @on = workflow["on"] = [workflow["on"]]
      set_attr_line_number(:@on, line_number)
    else
      @on = workflow["on"]
    end

    @meta["triggers"] = @on
    @meta["triggers"] = @on.keys if @on.is_a? Hash
  end

  def extract_normalized_jobs(workflow)
    @jobs = workflow["jobs"]
    @jobs.each do |job_name, job|
      @jobs[job_name] = job
      job["meta"] = {
        container: extract_container_info_from_job(job),
        permissions: normalize_permissions(job["permissions"])
      }

      job.fetch("steps", []).each do |step|
        step["meta"] = {
          secrets: extract_used_secrets(step["env"]),
          action: extract_action_data(step["uses"])
        }
      end
    end
  end

  def extract_used_secrets(env)
    return [] if env.nil?

    secrets = []
    env.each do |_k, v|
      next unless v.is_a? String

      secrets += v.scan(/secrets\.([a-zA-Z0-9_]+)/).flatten
    end

    secrets
  end

  def extract_action_data(action)
    return nil if action.nil?

    return extract_container_info_from_action(action) if action.start_with? "docker://"

    name, version = action.split("@", 2)
    author = name.split("/", 2)[0]
    local = author == "."
    { type: "action", name:, author:, version:, local: }
  end

  def extract_container_info_from_job(job)
    return nil if job["container"].nil?

    image = if job["container"].is_a? Hash
              job["container"]["image"]
            else
              job["container"]
            end

    extract_container_info_from_action(image)
  end

  def extract_container_info_from_action(action)
    return nil if action.nil?

    image, version = action.split("docker://").last.split(":", 2)

    {
      type: "container",
      image:,
      version:,
      full: "#{image}:#{version}"
    }
  end

  def extract_normalized_name(workflow)
    @name = workflow["name"]
    set_attr_line_number(:@name, 0)
  end

  def set_attr_line_number(key, line)
    instance_variable_get(key).instance_eval { |_x| define_singleton_method(:line, -> { line }) }
  end

  def copy_key_with_line(blob, src, dst)
    line = blob.keys.first { |k| k.to_sym == src.to_sym }.line

    new_key = String.new(dst).tap { |x| x.instance_eval { |_x| define_singleton_method(:line, -> { line }) } }
    # freezing it keeps ruby from making a copy w/o `line`
    new_key.freeze
    blob[new_key] = blob[src]
  end
end
