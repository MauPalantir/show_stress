#!/usr/bin/env ruby
require 'yaml'

class ShowStress
  class << self
    attr_reader :config, :vowel_regexp

    def phonemes_regexp
      to_regexp(ShowStress.config['renderings'].keys)
    end

    def consonant?(character)
      config['IPA']['consonants'].include? character
    end

    def to_regexp(array)
      Regexp.new('(' + array.map { |character| "(?:#{character})" }.join('|') + ')')
    end

    def orthographies_regexp(characters)
      regexp = ''

      characters.scan(phonemes_regexp) do |c|
        character = c[0]
        raise 'No orthographies found for this vowel: ' + character unless ShowStress.config['renderings'].key? character
        regexp += to_regexp(ShowStress.config['renderings'][character].to_a).to_s
      end

      Regexp.new(regexp)
    end
  end

  class Word
    attr_reader :word, :pronunciation, :stress_index, :stressed_vowel_value, :syllabes

    WORDS = {
      'individual' => 'ɪndɪˈvɪdʒʊ(ə)l',
      'vital' => 'ˈvaɪtɫ̩',
      'plate' => 'ˈpleɪt',
      'wyoming' => 'waɪˈoʊmɪŋ',
      'gypsy' => 'ˈdʒɪpsi',
      'readiness' => 'ˈrɛdɪnəs',
      'readonly' => 'ridˈəʊnli'
    }

    def initialize(word)
      @word = word
      @pronunciation = WORDS[word]
      @syllabes = pron.scan(ShowStress.vowel_regexp).flatten.compact
      @stress_index = if syllabes.size == 1
        0
      elsif pron[/['ˈ]/]
        pron.index(pron[/['ˈ]/])
      else
        raise 'cound not determine stressed syllabe'
      end
      @stressed_vowel_value = pron[stress_index..-1][ShowStress.vowel_regexp]
    end

    alias :pron :pronunciation

    def put_stressmark(index)
      w = word.dup
      w[index] = ShowStress::config['stressmarks'][w[index]]
      w
    end

    def stressed_syllabe
      stressed_vowel_index = stress_index + pron[stress_index..-1].index(ShowStress.vowel_regexp)

      next_vowel_index = stressed_vowel_index + pron[stress_index..-1].index(ShowStress.vowel_regexp)

      if ShowStress.consonant?(pron[next_vowel_index - 1]) && ShowStress.consonant?(pron[next_vowel_index - 1])
        return pron[stress_index + 1..next_vowel_index - 1]
      end

      pron[stress_index + 1..next_vowel_index]
    end

    def process
      stressed_vowel_orthography_regexp = ShowStress.orthographies_regexp(stressed_vowel_value)

      return put_stressmark(word.index(stressed_vowel_orthography_regexp)) if syllabes.size == 1 || stress_index == 0

      stressed_syllabe_orthography_regexp = ShowStress.orthographies_regexp(stressed_syllabe)

      raise "could not determine orthography for #{pronunciation}" unless word =~ stressed_syllabe_orthography_regexp

      word_stressed_syllabe = word.match(stressed_syllabe_orthography_regexp)[0]

      put_stressmark(word.index(stressed_syllabe_orthography_regexp) + word_stressed_syllabe.index(stressed_vowel_orthography_regexp))
    end
  end

  @config = YAML.load_file('orthography.yml')

  # A regexp that matches any vowel or diphtong.
  @vowel_regexp = Regexp.new(
    (config['IPA']['vowels'].map { |v| "(#{v})" } + config['IPA']['diphtongs'].map { |v| "(#{v})" }).join('|')
  )

  def self.run
    text = gets.chomp

    text.split(/\s/).each do |w|
      word = Word.new(w)

      puts word.process
    end
  end
end

ShowStress.run
