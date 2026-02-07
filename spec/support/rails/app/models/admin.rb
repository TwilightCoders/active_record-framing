class Admin < User

  # Inherit User's default_frame - don't override
  # This tests that STI child classes properly inherit parent frames

  # Use unscoped to clear User's default_scope (kind: 1) before applying Admin's (kind: 2)
  # Without unscoped, both would merge: kind = 1 AND kind = 2 (impossible!)
  default_scope do
    unscoped.select(arel_table[:id], arel_table[:kind], arel_table[:type]).where(kind: 2)
  end

  frame :special, -> {
    where(arel_table[:email].eq('special.person@example.com'))
  }

end
