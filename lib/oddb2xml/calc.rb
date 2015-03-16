# encoding: utf-8

require 'oddb2xml/util'
require 'yaml'

module Oddb2xml
 # Calc is responsible for analysing the columns "Packungsgrösse" and "Einheit"
 #
  GalenicGroup  = Struct.new("GalenicGroup", :oid, :descriptions)
  GalenicForm   = Struct.new("GalenicForm",  :oid, :descriptions, :galenic_group)

  class GalenicGroup
    def description(lang = 'de')
      descriptions[lang]
    end
  end

  class GalenicForm
    def description(lang = 'de')
      descriptions[lang]
    end
  end

  class Calc
    FluidForms = [
      'Ampulle(n)',
      'Beutel',
      'Bolus/Boli',
      'Bq',
      'Dose(n)',
      'Durchstechflasche(n)',
      'Einmaldosenbehälter',
      'Einzeldose(n)',
      'Fertigspritze',
      'Fertigspritze(n)',
      'Flasche(n)',
      'I.E.',
      'Infusionskonzentrat',
      'Infusionslösung',
      'Infusionsemulsion',
      'Inhalationen',
      'Inhalator',
      'Injektions-Set',
      'Injektions-Sets',
      'Injektor(en), vorgefüllt/Pen',
      'Klistier(e)',
      'MBq',
      'Pipetten',
      'Sachet(s)',
      'Spritze(n)',
      'Sprühstösse',
      'Stechampulle (Lyophilisat) und Ampulle (Solvens)',
      'Stechampulle',
      'Suspension',
      'Zylinderampulle(n)',
      'cartouches',
      'dose(s)',
      'flacon perforable',
      'sacchetto',
      'vorgefüllter Injektor',
      ]
    FesteFormen = [
      'Depotabs',
      'Dragée(s)',
      'Generator mit folgenden Aktivitäten:',
      'Filmtabletten',
      'Gerät',
      'Kapsel(n)',
      'Kautabletten',
      'Lutschtabletten',
      'Kugeln',
      'Ovulum',
      'Packung(en)',
      'Pflaster',
      'Schmelzfilme',
      'Set',
      'Strips',
      'Stück',
      'Suppositorien',
      'Tablette(n)',
      'Tüchlein',
      'Urethrastab',
      'Vaginalzäpfchen',
      'comprimé',
      'comprimé pelliculé',
      'comprimés',
      'comprimés à libération modifiée',
      'comprimés à croquer sécables',
      'imprägnierter Verband',
      'magensaftresistente Filmtabletten',
      'ovale Körper',
      'tube(s)',
    ]
    Measurements = [ 'g', 'kg', 'l', 'mg', 'ml', 'cm', 'GBq']
    Others = ['Kombipackung', 'emballage combiné' ]
    UnknownGalenicForm = 140
    UnknownGalenicGroup = 1
    Data_dir = File.expand_path(File.join(File.dirname(__FILE__),'..','..', 'data'))
    @@galenic_groups  = YAML.load_file(File.join(Data_dir, 'gal_groups.yaml'))
    @@galenic_forms   = YAML.load_file(File.join(Data_dir, 'gal_forms.yaml'))
    @@new_galenic_forms = []
    @@names_without_galenic_forms = []
    @@rules_counter = {}
    attr_accessor   :galenic_form, :unit, :pkg_size
    attr_reader     :name, :substances, :composition, :compositions, :composition_comment
    attr_reader     :selling_units, :count, :multi, :measure, :addition, :scale # s.a. commercial_form in oddb.org/src/model/part.rb
    def self.get_galenic_group(name, lang = 'de')
      @@galenic_groups.values.collect { |galenic_group|
        return galenic_group if galenic_group.descriptions[lang].eql?(name)
      }
      @@galenic_groups[1]
    end

    def self.report_conversion
      lines = [ '', '',
                'Report of used conversion rules',
                '-------------------------------',
                ''
                ]
      @@rules_counter.each{
        | key, value|
          lines << "#{key}: #{value} occurrences"
      }
      lines << ''
      lines << ''
      lines
    end

    def self.get_galenic_form(name, lang = 'de')
      @@galenic_forms.values.collect { |galenic_form|
        return galenic_form if galenic_form.descriptions[lang].eql?(name)
        if name and galenic_form.descriptions[lang].eql?(name.sub(' / ', '/'))
          return galenic_form
        end
      }
      @@galenic_forms[UnknownGalenicForm]
    end

    def self.dump_new_galenic_forms
      if @@new_galenic_forms.size > 0
        "\n\n\nAdded the following galenic_forms\n"+ @@new_galenic_forms.uniq.join("\n")
      else
        "\n\n\nNo new galenic forms added"
      end
    end
    def self.dump_names_without_galenic_forms
      if @@names_without_galenic_forms.size > 0
        "\n\n\nThe following products did not have a galenic form in column Präparateliste\n"+ @@names_without_galenic_forms.sort.uniq.join("\n")
      else
        "\n\n\nColumn Präparateliste has everywhere a name\n"
      end
    end
public
    SCALE_P = %r{pro\s+(?<scale>(?<qty>[\d.,]+)\s*(?<unit>[kcmuµn]?[glh]))}u
private
    def remove_duplicated_spaces(string)
      string ? string.to_s.gsub(/\s\s+/, ' ') : nil
    end
public
    # Update of active substances, etc picked up from oddb.org/src/plugin/swissmedic.rb update_compositions
    Composition   = Struct.new("Composition",  :name, :qty, :unit, :label)
    def update_compositions(active_substance)
      @active_substances = active_substance.split(/\s*,(?!\d|[^(]+\))\s*/u).collect { |name| capitalize(name) }.uniq

      res = []
      numbers = [ "A|I", "B|II", "C|III", "D|IV", "E|V", "F|VI" ]
      current = numbers.shift
      labels = []
      composition_text = composition.gsub(/\r\n?/u, "\n")
      puts "composition_text for #{name}: #{composition_text}" if composition_text.split(/\n/u).size > 1 and $VERBOSE
      compositions = composition_text.split(/\n/u).select do |line|
        if match = /^(#{current})\)([^:]+)/.match(line)
          labels.push [match[1], match[2]]
          current = numbers.shift
        end
      end
      puts "labels for #{name}: #{labels}" if labels.size > 0 and $VERBOSE
      if  composition_text.split(/\n/u).size > 1
        last_line = composition_text.split(/\n/u)[-1]
        @composition_comment = last_line
      else
        @composition_comment = nil
      end
      if compositions.empty?
        compositions.push composition_text.gsub(/\n/u, ' ')
      end
      agents = []
      comps = []
      units = 'U\.\s*Ph\.\s*Eur\.'
      name = 'dummy'
      ptrn = %r{(?ix)
                (^|[[:punct:]]|\bet|\bex)\s*#{Regexp.escape name}(?![:\-])
                (\s*(?<dose>[\d\-.]+(\s*(?:(Mio\.?\s*)?(#{units}|[^\s,]+))
                                    (\s*[mv]/[mv])?)))?
                (\s*(?:ut|corresp\.?)\s+(?<chemical>[^\d,]+)
                      \s*(?<cdose>[\d\-.]+(\s*(?:(Mio\.?\s*)?(#{units}|[^\s,]+))
                                          (\s*[mv]/[mv])?))?)?
              }u
      rep_1 = '----';   to_1 = '('
      rep_2 = '-----';  to_2 = ')'
      rep_3 = '------'; to_3 = ','
      compositions.each_with_index do |composition, idx|
        composition.gsub!(/'/, '')
        label = nil
        composition_text.split(/\n/u).each {
          |line|
          if m = /^(?<part_id>A|I|B|II|C|III|D|IV|E|V|F|VI)\)\s+(?<part_name>[^\s:, ]+):/.match(line)
            label = "#{m[:part_id]} #{m[:part_name]}"
          end
          filler = line.split(',')[-1].sub(/\.$/, '')
          filler_match = /^(?<name>[^,\d]+)\s*(?<dose>[\d\-.]+(\s*(?:(Mio\.?\s*)?(U\.\s*Ph\.\s*Eur\.|[^\s,]+))))/.match(filler)
          components = line.split(/([^\(]+\([^)]+\)[^,]+|),/).each {
            |component|
            next unless component.size > 0
            to_consider = component.strip.split(':')[-1] # remove label
            # very ugly hack to ignore ,()
            m = /^(?<name>[^,\d()]+)\s*(?<dose>[\d\-.]+(\s*(?:(Mio\.?\s*)?(U\.\s*Ph\.\s*Eur\.|[^\s,]+))))/.match(to_consider
                                                              .gsub(to_1, rep_1).gsub(to_2, rep_2).gsub(to_3, rep_3))
            if m2 = /^(|[^:]+:\s)(E\s+\d+)$/.match(component.strip)
              to_add = Composition.new(m2[2], '', '', nil)
              res << to_add
            elsif m
              dose = nil
              unit = nil
              name = m[:name].split(/\s/).collect{ |x| x.capitalize }.join(' ').strip.gsub(rep_3, to_3).gsub(rep_2, to_2).gsub(rep_1, to_1)
              dose = m[:dose].split(/\b\s*(?![.,\d\-]|Mio\.?)/u, 2) if m[:dose]
              if dose && (scale = SCALE_P.match(filler)) && dose[1] && !dose[1].include?('/')
                unit = dose[1] << '/'
                num = scale[:qty].to_f
                if num <= 1
                  unit << scale[:unit]
                else
                  unit << scale[:scale]
                end
              elsif dose.size == 2
                unit = dose[1]
              end
              to_add = Composition.new(name, dose ? dose[0].to_f : nil, unit ? unit.gsub(rep_3, to_3).gsub(rep_2, to_2).gsub(rep_1, to_1) : nil, label)
              res << to_add
            end
          }
        }
      end
      res
    end

    def initialize(name = nil, size = nil, unit = nil, active_substance = nil, composition= nil)
      @name = remove_duplicated_spaces(name)
      @pkg_size = remove_duplicated_spaces(size)
      @unit = unit
      # @pkg_size, @galenic_group, @galenic_form =
      search_galenic_info
      @composition = composition
      @measure = unit if unit and not @measure
      @measure = @galenic_form.description if @galenic_form and not @measure
      @galenic_form  ||= @@galenic_forms[UnknownGalenicForm]

      unless active_substance
        @compositions = []
        @active_substances = []
      else
        @compositions = update_compositions(active_substance)
      end
    end

    def galenic_group
      @@galenic_groups[@galenic_form.galenic_group]
    end

    # helper for generating csv
    def headers
      [ "name", "pkg_size", "selling_units", "measure",
        # "count", "multi", "addition", "scale", "unit",
        "galenic_form",
        "galenic_group"
        ]
    end
    def to_array
      [ @name, @pkg_size, @selling_units, @measure,
        # @count, @multi, @addition, @scale, @unit,
        galenic_form  ? galenic_form.description  : '' ,
        galenic_group ? galenic_group.description : ''
        ]
    end
    def galenic_form__xxx
      @galenic_form.description
    end
  private
    def capitalize(string)
      string.split(/\s+/u).collect { |word| word.capitalize }.join(' ')
    end

    def update_rule(rulename)
      @@rules_counter[rulename] ||= 0
      @@rules_counter[rulename] += 1
    end

    def get_selling_units(part_from_name_C, pkg_size_L, einheit_M)
      begin
        return pkg_size_to_int(pkg_size_L) unless part_from_name_C
        part_from_name_C = part_from_name_C.gsub(/[()]/, '_')
        Measurements.each{ |x|
                          if einheit_M and /^#{x}$/i.match(einheit_M)
                            puts "measurement in einheit_M #{einheit_M} matched: #{x}" if $VERBOSE
                            update_rule('measurement einheit_M')
                            @measure = x
                            return pkg_size_to_int(pkg_size_L, true)
                          end
                        }
        FesteFormen.each{ |x|
                          if part_from_name_C and (x.gsub(/[()]/, '_')).match(part_from_name_C)
                            puts "feste_form in #{part_from_name_C} matched: #{x}" if $VERBOSE
                            update_rule('feste_form name_C')
                            @measure = x
                            return pkg_size_to_int(pkg_size_L)
                          end
                          if einheit_M and x.eql?(einheit_M)
                            puts "feste_form in einheit_M #{einheit_M} matched: #{x}" if $VERBOSE
                            update_rule('feste_form einheit_M')
                            @measure = x
                            return pkg_size_to_int(pkg_size_L)
                          end
                        }
        FluidForms.each{ |x|
                          if part_from_name_C and x.match(part_from_name_C)
                            puts "liquid_form in #{part_from_name_C} matched: #{x}" if $VERBOSE
                            update_rule('liquid_form name_C')
                            @measure = x
                            return pkg_size_to_int(pkg_size_L, true)
                          end
                          if part_from_name_C and x.match(part_from_name_C.split(' ')[0])
                            puts "liquid_form in #{part_from_name_C} matched: #{x}" if $VERBOSE
                            update_rule('liquid_form first_part')
                            return pkg_size_to_int(pkg_size_L, true)
                          end
                          if einheit_M and x.eql?(einheit_M)
                            puts "liquid_form in einheit_M #{einheit_M} matched: #{x}" if $VERBOSE
                            update_rule('liquid_form einheit_M')
                            @measure = x
                            return pkg_size_to_int(pkg_size_L, true)
                          end
                        }
        Measurements.each{ |x|
                          if pkg_size_L and pkg_size_L.split(' ').index(x)
                            puts "measurement in pkg_size_L #{pkg_size_L} matched: #{x}" if $VERBOSE
                            update_rule('measurement pkg_size_L')
                            @measure = x
                            return pkg_size_to_int(pkg_size_L, true)
                          end
                        }
        puts "Could not find anything for name_C #{part_from_name_C} pkg_size_L: #{pkg_size_L} einheit_M #{einheit_M}" if $VERBOSE
        update_rule('unbekannt')
        return 'unbekannt'
      rescue RegexpError => e
        puts "RegexpError for M: #{einheit_M} pkg_size_L #{pkg_size_L} C: #{part_from_name_C}"
        update_rule('RegexpError')
        return 'error'
      end
    end

    def pkg_size_to_int(pkg_size, skip_last_part = false)
      return pkg_size if pkg_size.is_a?(Fixnum)
      return 1 unless pkg_size
      parts = pkg_size.split(/\s*x\s*/i)
      parts = parts[0..-2] if skip_last_part and parts.size > 1
      last_multiplier = parts[-1].to_i > 0 ? parts[-1].to_i : 1
      if parts.size == 3
        return parts[0].to_i * parts[1].to_i * last_multiplier
      elsif parts.size == 2
        return parts[0].to_i * last_multiplier
      elsif parts.size == 1
        return last_multiplier
      else
        return 1
      end
    end
    # Parse a string for a numerical value and unit, e.g. 1.5 ml
    def self.check_for_value_and_units(what)
      if m = /^([\d.]+)\s*(\D+)/.match(what)
        # return [m[1], m[2] ]
        return m[0].to_s
      else
        nil
      end
    end
    def search_galenic_info
      @substances = nil
      @substances = @composition.split(/\s*,(?!\d|[^(]+\))\s*/u).collect { |name| capitalize(name) }.uniq if @composition

      name = @name ? @name.clone : ''
      parts = name.split(',')
      form_name = nil
      if parts.size == 0
      elsif parts.size == 1
        @@names_without_galenic_forms << name
      else
        parts[1..-1].each{
          |part|
          form_name = part.strip
          @galenic_form = Calc.get_galenic_form(form_name)
          # puts "oid #{UnknownGalenicForm} #{@galenic_form.oid} for #{name}"
          break unless @galenic_form.oid == UnknownGalenicForm
          if @galenic_form.oid == UnknownGalenicForm
            @galenic_form =  GalenicForm.new(0, {'de' => remove_duplicated_spaces(form_name.gsub(' +', ' '))}, @@galenic_forms[UnknownGalenicForm] )
            @@new_galenic_forms << form_name
          end
        }
      end
      @name = name.strip
      if @pkg_size.is_a?(Fixnum)
        @count = @pkg_size
        res = [@pkg_size]
      else
        res = @pkg_size ? @pkg_size.split(/x/i) : []
        if res.size >= 1
          @count = res[0].to_i
        else
          @count = 1
        end
      end
      # check whether we find numerical and units
      if res.size >= 2
        if (result = Calc.check_for_value_and_units(res[1].strip)) != nil
          @multi = result[1].to_f
        else
          @multi = res[1].to_i
        end
      else
        @multi = 1
      end
      @addition = 0
      @scale = 1
      @selling_units = get_selling_units(form_name, @pkg_size, @unit)
    end
  end
end