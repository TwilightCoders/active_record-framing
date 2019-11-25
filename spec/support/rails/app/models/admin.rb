class Admin < User

  default_frame {
    where(arel_table[:kind].eq(2))
    # where(kind: 1)
  }

  default_scope {
    # select(arel_table[Arel.star], arel_table[:tableoid])#
    select(arel_table[:id], arel_table[:kind]).where(kind: 2)
  }

end
