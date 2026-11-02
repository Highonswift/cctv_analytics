/// The daily story questions, spoken aloud each morning in Tamil.
///
/// Seeded from the roadmap: his childhood, his village, his TNSTC years,
/// breakdowns he fixed, people he worked with. Every question asks him as the
/// expert; none of them test him. Appa should review and rewrite these in his
/// own spoken Tamil at the weekly review, and his three willing TNSTC stories
/// from Phase 0 should go at the top.
class StoryPrompt {
  const StoryPrompt(this.id, this.tamil, this.english);
  final String id;
  final String tamil;

  /// For the team only; never shown to Appa.
  final String english;
}

const storyPrompts = <StoryPrompt>[
  StoryPrompt(
    'tnstc-first-day',
    'TNSTC-யில் உங்கள் முதல் வேலை நாள் எப்படி இருந்தது?',
    'What was your first day of work at TNSTC like?',
  ),
  StoryPrompt(
    'hardest-breakdown',
    'நீங்கள் சரிசெய்த மிகக் கடினமான பஸ் பழுது எது? அதை எப்படிக் கண்டுபிடித்தீர்கள்?',
    'What was the hardest bus breakdown you fixed, and how did you find the fault?',
  ),
  StoryPrompt(
    'village-childhood',
    'நீங்கள் சிறுவயதில் வளர்ந்த ஊரைப் பற்றிச் சொல்லுங்கள். வீடு எப்படி இருந்தது?',
    'Tell us about the village you grew up in. What was the house like?',
  ),
  StoryPrompt(
    'first-mentor',
    'வேலையில் உங்களுக்கு முதலில் கற்றுக்கொடுத்தவர் யார்? அவரிடம் என்ன கற்றீர்கள்?',
    'Who first taught you at work, and what did you learn from them?',
  ),
  StoryPrompt(
    'depot-friend',
    'டிப்போவில் உங்களுக்கு நெருக்கமான நண்பர் யார்? அவரைப் பற்றி ஒரு நினைவு சொல்லுங்கள்.',
    'Who was your closest friend at the depot? Share one memory of them.',
  ),
  StoryPrompt(
    'first-salary',
    'உங்கள் முதல் சம்பளம் எவ்வளவு? அதை வைத்து என்ன செய்தீர்கள்?',
    'How much was your first salary, and what did you do with it?',
  ),
  StoryPrompt(
    'school-days',
    'பள்ளிக்கூட நாட்களில் உங்களுக்குப் பிடித்த ஆசிரியர் யார்? ஏன்?',
    'Who was your favourite teacher at school, and why?',
  ),
  StoryPrompt(
    'night-shift',
    'இரவு ஷிஃப்டில் நடந்த மறக்க முடியாத ஒரு சம்பவம் சொல்லுங்கள்.',
    'Tell us one unforgettable thing that happened on a night shift.',
  ),
  StoryPrompt(
    'engine-advice',
    'ஒரு இளைஞர் முதல் முறையாக என்ஜின் வேலை கற்றுக்கொள்ள வந்தால், நீங்கள் முதலில் என்ன சொல்வீர்கள்?',
    'If a young person came to learn engine work, what would you tell them first?',
  ),
  StoryPrompt(
    'wedding-day',
    'உங்கள் திருமண நாளைப் பற்றிச் சொல்லுங்கள். அன்று என்ன நடந்தது?',
    'Tell us about your wedding day. What happened that day?',
  ),
  StoryPrompt(
    'festival-memory',
    'சிறுவயதில் பொங்கல் எப்படிக் கொண்டாடுவீர்கள்?',
    'How did you celebrate Pongal as a child?',
  ),
  StoryPrompt(
    'proudest-work',
    'வேலையில் நீங்கள் மிகவும் பெருமைப்பட்ட ஒரு நாள் எது?',
    'What is one day at work you were most proud of?',
  ),
  StoryPrompt(
    'old-buses',
    'அந்தக் காலத்து பஸ்களுக்கும் இப்போதைய பஸ்களுக்கும் என்ன வித்தியாசம்?',
    "What is the difference between the buses of those days and today's?",
  ),
  StoryPrompt(
    'father-memory',
    'உங்கள் அப்பாவைப் பற்றி ஒரு நினைவு சொல்லுங்கள். அவர் என்ன வேலை செய்தார்?',
    'Share a memory of your father. What work did he do?',
  ),
  StoryPrompt(
    'mother-cooking',
    'உங்கள் அம்மா சமைத்ததில் உங்களுக்கு மிகவும் பிடித்தது எது?',
    'What was your favourite dish your mother cooked?',
  ),
  StoryPrompt(
    'first-bike',
    'உங்கள் முதல் சைக்கிள் அல்லது வண்டி எது? அதை எப்படி வாங்கினீர்கள்?',
    'What was your first cycle or vehicle, and how did you buy it?',
  ),
  StoryPrompt(
    'rain-trouble',
    'பெரிய மழையில் பஸ் நின்றுபோன ஒரு அனுபவம் உண்டா?',
    'Was there a time a bus broke down in heavy rain?',
  ),
  StoryPrompt(
    'tool-favourite',
    'உங்களுக்கு மிகவும் பிடித்த கருவி எது? ஏன்?',
    'What was your favourite tool, and why?',
  ),
  StoryPrompt(
    'son-childhood',
    'உங்கள் மகன் சிறுவனாக இருந்தபோது செய்த ஒரு குறும்பு சொல்லுங்கள்.',
    'Tell us about something mischievous your son did as a child.',
  ),
  StoryPrompt(
    'lesson-life',
    'வாழ்க்கையில் நீங்கள் கற்ற மிக முக்கியமான பாடம் என்ன?',
    'What is the most important lesson life has taught you?',
  ),
  StoryPrompt(
    'colleagues-together',
    'வேலை செய்த காலத்தில் சக ஊழியர்கள் ஒன்றாகச் சேர்ந்து செய்த ஒரு நல்ல விஷயம் சொல்லுங்கள்.',
    'Tell us about a good thing your colleagues did together.',
  ),
  StoryPrompt(
    'retirement-day',
    'ஓய்வு பெற்ற அன்று டிப்போவில் என்ன நடந்தது?',
    'What happened at the depot on the day you retired?',
  ),
  StoryPrompt(
    'village-temple',
    'உங்கள் ஊர்க் கோயில் திருவிழா பற்றிச் சொல்லுங்கள்.',
    'Tell us about the festival at your village temple.',
  ),
  StoryPrompt(
    'fix-at-home',
    'வீட்டில் நீங்கள் சரிசெய்த ஒன்றைப் பற்றிச் சொல்லுங்கள். எப்படிச் செய்தீர்கள்?',
    'Tell us about something you fixed at home. How did you do it?',
  ),
  StoryPrompt(
    'long-route',
    'நீங்கள் அறிந்த மிக நீண்ட பஸ் ரூட் எது? அதில் என்ன சவால்கள் இருந்தன?',
    'What is the longest bus route you knew, and what were its challenges?',
  ),
  StoryPrompt(
    'advice-grandchild',
    'பேரக்குழந்தைகளுக்கு நீங்கள் சொல்ல விரும்பும் ஒரு அறிவுரை என்ன?',
    'What is one piece of advice you want to give your grandchildren?',
  ),
  StoryPrompt(
    'first-film',
    'நீங்கள் தியேட்டரில் பார்த்த முதல் சினிமா எது? யாருடன் போனீர்கள்?',
    'What was the first film you saw in a theatre, and who did you go with?',
  ),
  StoryPrompt(
    'safety-rule',
    'வேலையில் நீங்கள் எப்போதும் கடைப்பிடித்த ஒரு பாதுகாப்பு விதி எது?',
    'What is one safety rule you always followed at work?',
  ),
  StoryPrompt(
    'amma-first-meet',
    'அம்மாவை முதன்முதலில் பார்த்தது எப்போது? எப்படி இருந்தது?',
    'When did you first meet Amma? What was it like?',
  ),
  StoryPrompt(
    'change-seen',
    'உங்கள் வாழ்நாளில் ஊரில் நீங்கள் பார்த்த மிகப்பெரிய மாற்றம் என்ன?',
    'What is the biggest change you have seen in your town in your lifetime?',
  ),
];
