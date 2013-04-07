class SeparateProgramAndResultFromSubmission < ActiveRecord::Migration
  def up
    Submission.all.each do |submission|
      submission.detail = SubmissionDetail.new program: submission.program, result: submission.result
      submission.save
    end
    remove_column :submissions, :program
    remove_column :submissions, :result
  end

  def down
    add_column :submissions, :program, :text
    add_column :submissions, :result, :text
    Submission.all.each do |submission|
      submission.program = submission.detail.program
      submission.result = submission.detail.result
      submission.detail.destroy
      submission.save
    end
  end
end
