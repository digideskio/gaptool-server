namespace :ec2 do
  desc "Rehash instances"
  task :rehash do |t|
    EC2.rehash
  end

  desc "Rehash single attribute of all instances"
  task :rehash_attr_all, [:property] do |t, args|
    if args[:property].nil?
      puts "Missing property"
      return 1
    end
    EC2.rehash_property(args[:property])
  end

  desc "Rehash ec2 attributes for a single instance"
  task :rehash_attrs_for [:instance] do |t, args|
    if args[:instance].nil?
      puts "Missing instance"
      return 1
    end
    res = EC2.rehash_properties_for_instance(args[:instance])
    return 1 unless res
  end

  desc "Rehash a single property for an instance"
  task :rehash_attr_for [:instance, :property] do |t, args|
    if args[:instance].nil?
      puts "Missing instance"
      return 1
    end
    if args[:property].nil?
      puts "Missing property"
      return 1
    end
    res = EC2.rehash_property_for_instance(args[:property], args[:instance])
    if res
      puts "#{property} for instance #{instance} set to '#{res}'"
    else
      return 1
    end
  end

end
