# encoding: UTF-8

def generate_user(from, to)
  from.upto(to) do |x|
    user = User.new(
        handle: 'test_user_' + x.to_s,
        password: 'abc',
        password_confirmation: 'abc',
        information: UserInformation.new(
            real_name: 'test_user_' + x.to_s,
            school: 'test school',
            email: "test_user_#{x}@test.com",
            signature: 'test signature',
        )
    )
    user.save!
  end
  puts 'user ok'
end

def generate_problem(from, to)
  from.upto(to) do |x|
    problem = Problem.new(
        title: 'Test Problem' + x.to_s,
        source: 'Test',
        status: 'normal',
        content: ProblemContent.new(
            time_limit: '1s',
            memory_limit: '64MB',
            description: 'Test Problem' + x.to_s,
            input: 'Test Problem' + x.to_s,
            output: 'Test Problem' + x.to_s,
        )
    )
    problem.save!
    SampleTestData.create!(
        problem: problem,
        case_no: 0,
        input: "hello\nworld",
        output: "yes\nhero",
    )
  end
  puts 'problem ok'
end

def generate_tags(from, to, record_num)
  problems = Problem.all.to_a
  from.upto(to) do |x|
    tag = Tag.new(name: "Tag #{x}")
    problems.each do |problem|
      if rand(problems.size) < record_num
        tag.problems << problem
      end
    end
    tag.save!
  end
  puts 'tag ok'
end

def generate_submission(num)
  users = User.all.to_a
  problems = Problem.all.to_a
  num.times do
    attr = {
        user: users[rand(users.size)],
        problem: problems[rand(problems.size)],
        program: 'hello, world',
        language: APP_CONFIG.program_languages.keys[rand(3)].to_s,
        platform: APP_CONFIG.judge_platforms.keys[rand(2)].to_s,
        time_used: rand(5000) + 1000,
        memory_used: rand(5000) + 1000,
        code_size: rand(5000) + 500,
        code_length: rand(200) + 50,
        status: 'judged',
        result: ''
    }
    if rand(2) == 0
      attr[:score] = 100
    else
      attr[:score] = rand(20) * 5
    end
    Submission.create! attr
  end
  puts 'submission ok'
end

def generate_topic(from, to)
  users = User.all.to_a
  problems = Problem.all.to_a
  from.upto(to) do |x|
    Topic.create!(
        {
            user: users[rand(users.size)],
            problem: rand(3) == 0 ? nil : problems[rand(problems.size)],
            title: "Topic #{x}",
            content: "this is content for topic #{x}",
            program: 'hello world',
            language: APP_CONFIG.program_languages.keys[rand(3)].to_s,
            top: rand(100) == 0
        },
        without_protection: true
    )
  end
  puts 'topic ok'
end

def generate_primary_reply(from, to)
  users = User.all.to_a
  topics = Topic.all.to_a
  from.upto(to) do |x|
    PrimaryReply.create!(
        user: users[rand(users.size)],
        topic: topics[rand(topics.size)],
        content: "this is content for primary reply #{x}",
        program: 'hello world',
        language: APP_CONFIG.program_languages.keys[rand(3)].to_s
    )
  end
  puts 'primary reply ok'
end

def generate_secondary_reply(from, to)
  users = User.all.to_a
  primary_replies = PrimaryReply.includes(:topic).all.to_a
  from.upto(to) do |x|
    SecondaryReply.create!(
        user: users[rand(users.size)],
        primary_reply: primary_replies[rand(primary_replies.size)],
        content: "this is content for secondary reply #{x}"
    )
  end
  puts 'secondary reply ok'
end

def generate_notification(user_id, num)
  user = User.find_by_id user_id
  num.times do |x|
    Notification.create!(
        user: user,
        content: "System notification #{x}"
    )
  end
  puts 'notification ok'
end

def generate_message(to, num)
  user = User.find_by_id to
  users = User.all.to_a
  num.times do |x|
    tmp = nil
    loop do
      tmp = users[rand(users.size)]
      break if tmp.id != user.id
    end
    Message.create!(
        from: tmp,
        to: user,
        content: "Message #{x * 2}"
    )
    Message.create!(
        from: user,
        to: tmp,
        content: "Message #{x * 2 + 1}"
    )
  end
  puts 'message ok'
end

def main
end

main
