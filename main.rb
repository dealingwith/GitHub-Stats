require 'octokit'
require 'csv'
require 'awesome_print'
require 'colorize'
require './utils'

# takes one argument at the moment, number of issues to fetch from the GitHub API, max 99
# if no argument is given, it will fetch ALL issues using the max page size of 100
if ARGV[0] && ARGV[0].to_i > 0 && ARGV[0].to_i < 100
  num_issues = ARGV[0].to_i
else
  num_issues = 100
end

client = Octokit::Client.new(:access_token => ENV['GITHUB_TOKEN'], per_page: num_issues)
issues = client.issues('ApproveShield/ApproveShield', state: 'all', sort: 'updated', direction: 'desc')
unless ARGV[0] # fetch ALL issues using the max page size of 100
  issues.concat client.get(client.last_response.rels[:next].href) until client.last_response.rels[:next].nil?
end

puts "Total issues & PRs: #{issues.size}"

# group by month
# remove anything older than 12 months
issues_by_date = issues.delete_if { |issue| issue[:closed_at]&.to_date&.year == Time.now.year - 1 && issue[:closed_at]&.to_date&.month <= Time.now.month }
months_represented = issues_by_date.map { |issue| "#{issue[:closed_at]&.to_date&.year}#{issue[:closed_at]&.to_date&.month}" }.uniq
puts "Months represented:".yellow
puts "#{months_represented}".yellow
issues_by_date = issues.group_by { |issue| issue[:closed_at]&.to_date&.month || 0 }
issues_by_date = issues_by_date.sort_by { |month, _| month }.to_h
File.write 'issues.rb', issues_by_date.to_s # for debugging

# CSV
CSV.open('issues.csv', 'w', headers: ['Month', 'Month Name', 'Total Issues', 'PRs', 'Bugs', 'Maint', 'Percent Bugs/Maint', 'MTTR all Issues', 'MTTR Maint', 'MTTR Bugs'], write_headers: true) do |csv|

  issues_by_date.each_with_index do |(month, issues), index|
    month_label = case month
                  when 0
                    'Current Open'
                  else
                    Date::MONTHNAMES[month]
                  end
    puts "-- #{month_label} --".yellow

    issue_durations = []
    issues.each do |issue|
      unless issue[:html_url].include? 'pull'
        issue_duration = (issue[:closed_at] || Time.now) - issue[:created_at]
        issue_durations.push issue_duration
      end
    end

    bug_durations = []
    issues.each do |issue|
      unless issue[:html_url].include? 'pull'
        if issue[:labels].any? {|label| label[:name] == 'bug'}
          bug_duration = (issue[:closed_at] || Time.now) - issue[:created_at]
          bug_durations.push bug_duration
        end
      end
    end

    maintenance_durations = []
    issues.each do |issue|
      unless issue[:html_url].include? 'pull'
        if issue[:labels].any? {|label| label[:name] == 'maintenance'}
          maintenance_duration = (issue[:closed_at] || Time.now) - issue[:created_at]
          maintenance_durations.push maintenance_duration
        end
      end
    end

    total_issues = issue_durations.size
    puts "  Total Issues: #{total_issues}"
    total_prs = issues.size - total_issues
    puts "  Total PRs: #{total_prs}"
    total_bugs = bug_durations.size
    puts "  Total bugs: #{total_bugs}"
    total_maintenance = maintenance_durations.size
    puts "  Total maintenance: #{total_maintenance}"
    total_bugs_and_maintenance = total_bugs + total_maintenance
    puts "  Total bugs and maintenance: #{total_bugs_and_maintenance}"
    if (total_bugs_and_maintenance > 0 && total_issues > 0)
      percent_bugs_and_maintenance = (total_bugs_and_maintenance.to_f / total_issues.to_f).round(2)
    else
      percent_bugs_and_maintenance = 0
    end
    puts "  Percent bugs/maint: #{percent_bugs_and_maintenance}"

    total_duration = issue_durations.map { |issue_duration| issue_duration }.reduce(:+) || 0
    if (total_duration > 0)
      duration_average = total_duration / issue_durations.length
    else
      duration_average = 0
    end

    bug_total_duration = bug_durations.map { |bug_duration| bug_duration }.reduce(:+) || 0
    if (bug_total_duration > 0)
      bug_duration_average = bug_total_duration / bug_durations.length
    else
      bug_duration_average = 0
    end

    maintenance_total_duration = maintenance_durations.map { |maintenance_duration| maintenance_duration }.reduce(:+) || 0
    if (maintenance_total_duration > 0)
      maintenance_duration_average = maintenance_total_duration / maintenance_durations.length
    else
      maintenance_duration_average = 0
    end

    mttr_all_issues = Utils.seconds_to_days(duration_average)
    puts "  MTTR for all issues: #{mttr_all_issues}"
    mttr_maintenance = Utils.seconds_to_days(maintenance_duration_average)
    puts "  MTTR for maint: #{mttr_maintenance}"
    mttr_bugs = Utils.seconds_to_days(bug_duration_average)
    puts "  MTTR for bugs: #{mttr_bugs}"

    csv << [month, month_label, issues.size, total_prs, total_bugs, total_maintenance, percent_bugs_and_maintenance, mttr_all_issues, mttr_maintenance, mttr_bugs]
  end # issues_by_date.each_with_index

end # CSV
