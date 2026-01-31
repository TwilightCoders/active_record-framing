# Problems So Far

- spec/active_record/framing/reframing_spec.rb:36
User.joins(posts: :comments).reframe(posts: Post::Deleted).to_sql
User default scope still has interpolation variables in frame ($1)

Reframe doesn't rename all tables

Thoughts:
Handle on table object (change name when reframe is triggered)
Would need to track nesting—subqueries quering from original table name should not be changed.
