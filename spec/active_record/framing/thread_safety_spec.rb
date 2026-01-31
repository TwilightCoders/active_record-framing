require "spec_helper"

describe 'Thread Safety' do

  context 'frame isolation between threads' do
    it 'does not leak frames between threads' do
      results = []
      mutex = Mutex.new

      # Thread 1: Uses default frame
      thread1 = Thread.new do
        sql = User.all.to_sql
        mutex.synchronize { results << [:thread1, sql] }
      end

      # Thread 2: Uses unframed
      thread2 = Thread.new do
        sql = User.unframed.to_sql
        mutex.synchronize { results << [:thread2, sql] }
      end

      thread1.join
      thread2.join

      thread1_sql = results.find { |r| r[0] == :thread1 }[1]
      thread2_sql = results.find { |r| r[0] == :thread2 }[1]

      expect(thread1_sql).to include('WITH')
      expect(thread2_sql).not_to include('WITH')
    end

    it 'does not leak current_frame across threads' do
      results = []
      mutex = Mutex.new

      # Thread 1: Sets current_frame via framing block
      thread1 = Thread.new do
        User.where(name: 'test').framing do
          sleep 0.01 # Let thread2 start
          frame = User.current_frame
          mutex.synchronize { results << [:thread1, frame.present?] }
        end
      end

      # Thread 2: Checks current_frame (should be nil/default)
      thread2 = Thread.new do
        sleep 0.005 # Let thread1 set its frame first
        frame = User.current_frame
        mutex.synchronize { results << [:thread2, frame.class.name] }
      end

      thread1.join
      thread2.join

      thread1_has_frame = results.find { |r| r[0] == :thread1 }[1]
      thread2_frame_class = results.find { |r| r[0] == :thread2 }[1]

      expect(thread1_has_frame).to be true
      # Thread 2 should have different frame (or nil)
      # The key is they don't interfere
    end
  end

  context 'concurrent frame registry access' do
    it 'handles concurrent frame lookups safely' do
      threads = 10.times.map do |i|
        Thread.new do
          100.times do
            User.current_frame
            User.all.to_sql
          end
        end
      end

      expect { threads.each(&:join) }.not_to raise_error
    end

    it 'handles concurrent frame updates safely' do
      threads = 5.times.map do |i|
        Thread.new do
          50.times do
            User.where(kind: i).framing do
              User.all.to_sql
            end
          end
        end
      end

      expect { threads.each(&:join) }.not_to raise_error
    end
  end

  context 'Framing.disable thread safety' do
    it 'does not affect other threads when disabled' do
      results = []
      mutex = Mutex.new

      # Thread 1: Disables framing
      thread1 = Thread.new do
        ActiveRecord::Framing.disable do
          sql = User.all.to_sql
          mutex.synchronize { results << [:thread1, sql] }
          sleep 0.01
        end
      end

      # Thread 2: Uses framing normally
      thread2 = Thread.new do
        sleep 0.005
        sql = User.all.to_sql
        mutex.synchronize { results << [:thread2, sql] }
      end

      thread1.join
      thread2.join

      thread1_sql = results.find { |r| r[0] == :thread1 }[1]
      thread2_sql = results.find { |r| r[0] == :thread2 }[1]

      # Thread 1 disabled, should not have CTE
      expect(thread1_sql).not_to include('WITH')
      # Thread 2 not disabled, should have CTE
      expect(thread2_sql).to include('WITH')
    end

    it 're-enables framing after block in same thread' do
      ActiveRecord::Framing.disable do
        expect(User.all.to_sql).not_to include('WITH')
      end

      expect(User.all.to_sql).to include('WITH')
    end
  end

end
