module IpgeobaseExt
  inline do |builder|
    #builder.include '"ipgeobase.h"'
    #builder.add_compile_flags "-I."
    builder.prefix <<-INLINE
    #ifndef _IPGEOBASE_H_
    #define _IPGEOBASE_H_


    #include <stdio.h>
    #include <unistd.h>
    #include <sys/time.h>

    #define BUF_SIZE 1024
    #define CITY_SIZE 40


    typedef struct ip_tag1 {
    	unsigned int start, stop;
    	char city[CITY_SIZE];
    	unsigned int slave, n_slave;
    } IpEntryMaster;

    typedef struct ip_tag2 {
    	unsigned int start, stop;
    	char city[CITY_SIZE];
    } IpEntrySlave;

    typedef struct ip_tags {
    	size_t master_count, slave_count;
    	IpEntryMaster* master;
    	IpEntrySlave* slave;
    } IpEntries;

    extern VALUE IpEntriesClass;

    #endif /* _IPGEOBASE_H_ */
    INLINE
    builder.c <<-INLINE
    
    VALUE load_database(char* path) {
    	char buf[BUF_SIZE];
    	char master_path[1024], slave_path[1024];
    	IpEntries *entries;
    	FILE* db;
    	int i;

      if(!path || !*path) return Qnil;
        
      entries = (IpEntries *)malloc(sizeof(IpEntries));
    	sprintf(master_path, "%s/cidr_ru_master_index.db", path);
    	db = fopen(master_path, "r+");
    	if(!db) return Qnil;
    	  
    	entries->master_count = 0;
    	while(fgets(buf, sizeof(buf), db)) {
    		entries->master_count++;
    	}
    	entries->master = (IpEntryMaster *)calloc(entries->master_count, sizeof(IpEntryMaster));
    	fseek(db, 0, SEEK_SET);
    	i = 0;
    	while(fgets(buf, sizeof(buf), db)) {
    		IpEntryMaster* entry = entries->master + i;
    		char *ptr;
    		sscanf(buf, "%d\t%d\t%*s - %*s\t%*s\t%s", &entry->start, &entry->stop, entry->city);
    		ptr = buf + strlen(buf) - 1;
    		while(*ptr != '\t') ptr--; ptr--;
    		while(*ptr != '\t') ptr--; 
    		ptr++;
    		sscanf(ptr, "%d\t%d", &entry->slave, &entry->n_slave);
    		i++;
    	}
    	fclose(db);

    	sprintf(slave_path, "%s/cidr_ru_slave_index.db", path);
    	db = fopen(slave_path, "r+");
    	if(!db) return Qnil;

    	entries->slave_count = 0;
    	while(fgets(buf, sizeof(buf), db)) {
    		entries->slave_count++;
    	}
    	entries->slave = (IpEntrySlave *)calloc(entries->slave_count, sizeof(IpEntrySlave));
    	fseek(db, 0, SEEK_SET);
    	i = 0;
    	while(fgets(buf, sizeof(buf), db)) {
    		IpEntrySlave* entry = entries->slave + i;
    		sscanf(buf, "%d\t%d\t%*s - %*s\t%*s\t%s", &entry->start, &entry->stop, entry->city);
    		i++;
    	}
    	fclose(db);

    	return Data_Wrap_Struct(rb_path2class("Ipgeobase::IpEntry"), 0, 0, entries);
    }

    INLINE
    
    builder.c <<-INLINE
    VALUE internal_lookup(VALUE rb_entries, char* ip_s) {
    	int master_index;
    	IpEntries *entries;
    	char* city;
    	unsigned int ip;
    	Data_Get_Struct(rb_entries, IpEntries, entries);
    	
    	{
    	  unsigned int c1,c2,c3,c4;
      	sscanf(ip_s, "%d.%d.%d.%d", &c1, &c2, &c3, &c4);
      	ip = c1 * 256 * 256 * 256 + c2 * 256 * 256 + c3 * 256 + c4;
    	}
    	
    	{
      	int i = -1, min, max;
      	int ok = 0;
      	min = 0;
      	max = entries->master_count - 1;
      	
      	while(min < max) {
      		IpEntryMaster* entry;
      		i = (min + max)/2;
      		entry = entries->master + i;

      		if(entry->stop < ip) {
      			min = i+1;
      		} else if(entry->start > ip) {
      			max = i;
      		} else if(entry->start <= ip && ip <= entry->stop){
      		  ok = 1;
      			master_index = i;
      			break;
      		}
      	}
      	
      	if(!ok) return Qnil;
      	
      	{
        	IpEntryMaster *master;
        	master = entries->master + master_index;
        	return rb_str_new2(master->city);
      	}
    	}
    	
    	{
      	IpEntryMaster *master;
      	int size, i, index = -1;
      	master = entries->master + master_index;
      	size = master->stop - master->start + 1;
      	for(i = master->slave; i <= master->slave + master->n_slave; i++) {
      		IpEntrySlave *entry = entries->slave + i;
      		if(entry->start <= ip && ip <= entry->stop && 
      			entry->stop - entry->start < size) {
      			size = entry->stop - entry->start;
      			index = i;
      		}
      	}
      	city = index > -1 ? entries->slave[index].city : master->city;
    	  
    	}

    	return rb_str_new2(city);
    }

    
    INLINE
  end
  
  
  
end