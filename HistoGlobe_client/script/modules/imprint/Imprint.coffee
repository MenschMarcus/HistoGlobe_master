window.HG ?= {}

class HG.Imprint

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: () ->

    # create imprint link
    @_link = new HG.Div 'imprint-link', 'no-text-select'
    $(@_link.elem()).html "Impressum &nbsp; &copy; HistoGlobe   2010-" + new Date().getFullYear()

    $(@_link.elem()).click () =>
      @showBox()

    # create imprint
    @_imprintOverlay = new HG.Div 'imprint-overlay'
    @_imprintBox = new HG.Div 'imprint-box'

    @_imprintClose = new HG.Span null, 'close-button'
    $(@_imprintClose.elem()).html 'x'

    @_imprintText = new HG.Div 'imprint-text'
    @_imprintText.elem().innerHTML = '
      <h1>Impressum</h1>
      <p>Angaben gemäß § 5 TMG</p>
      <h2>Verantwortlich für den Inhalt nach § 55 Abs. 2 RStV:</h2>
        <p>
          Marcus Kossatz<br />
          Brunnenstraße 3<br />
          99423 Weimar
        </p>
        <p>
          E-Mail: marcus.kossatz@histoglobe.com<br />
          Tel: 0170 429 46 24
        </p>
        </p>
      <h2>Haftungsausschluss</h2>
        <p>Alle in HistoGlobe verwendeten Informationen, Bilder und Texte stammen aus der <a href:"http://de.wikipedia.org">deutschsprachigen Wikipedia</a>. HistoGlobe ist zwar stolz darauf, einzig frei zugängliches Wissen aus der größten Online-Enzyklopädie zu visualisieren, übernimmt jedoch keine Haftung und keine Gewähr für die Richtigkeit der Informationen.</p>
      <h3>Haftung für Inhalte</h3>
        <p>Die Inhalte unserer Seiten wurden mit größter Sorgfalt erstellt. Für die Richtigkeit, Vollständigkeit und Aktualität der Inhalte können wir jedoch keine Gewähr übernehmen. Als Diensteanbieter sind wir gemäß § 7 Abs.1 TMG für eigene Inhalte auf diesen Seiten nach den allgemeinen Gesetzen verantwortlich. Nach §§ 8 bis 10 TMG sind wir als Diensteanbieter jedoch nicht verpflichtet, übermittelte oder gespeicherte fremde Informationen zu überwachen oder nach Umständen zu forschen, die auf eine rechtswidrige Tätigkeit hinweisen. Verpflichtungen zur Entfernung oder Sperrung der Nutzung von Informationen nach den allgemeinen Gesetzen bleiben hiervon unberührt. Eine diesbezügliche Haftung ist jedoch erst ab dem Zeitpunkt der Kenntnis einer konkreten Rechtsverletzung möglich. Bei Bekanntwerden von entsprechenden Rechtsverletzungen werden wir diese Inhalte umgehend entfernen.</p>
      <h3>Haftung für Links</h3></p>
        <p>Unser Angebot enthält Links zu externen Webseiten Dritter, auf deren Inhalte wir keinen Einfluss haben. Deshalb können wir für diese fremden Inhalte auch keine Gewähr übernehmen. Für die Inhalte der verlinkten Seiten ist stets der jeweilige Anbieter oder Betreiber der Seiten verantwortlich. Die verlinkten Seiten wurden zum Zeitpunkt der Verlinkung auf mögliche Rechtsverstöße überprüft. Rechtswidrige Inhalte waren zum Zeitpunkt der Verlinkung nicht erkennbar. Eine permanente inhaltliche Kontrolle der verlinkten Seiten ist jedoch ohne konkrete Anhaltspunkte einer Rechtsverletzung nicht zumutbar. Bei Bekanntwerden von Rechtsverletzungen werden wir derartige Links umgehend entfernen.</p>
      <h3>Urheberrecht</h3>
        <p>Die durch die Seitenbetreiber erstellten Inhalte und Werke auf diesen Seiten unterliegen dem deutschen Urheberrecht. Die Vervielfältigung, Bearbeitung, Verbreitung und jede Art der Verwertung außerhalb der Grenzen des Urheberrechtes bedürfen der schriftlichen Zustimmung des jeweiligen Autors bzw. Erstellers. Downloads und Kopien dieser Seite sind nur für den privaten, nicht kommerziellen Gebrauch gestattet. Soweit die Inhalte auf dieser Seite nicht vom Betreiber erstellt wurden, werden die Urheberrechte Dritter beachtet. Insbesondere werden Inhalte Dritter als solche gekennzeichnet. Sollten Sie trotzdem auf eine Urheberrechtsverletzung aufmerksam werden, bitten wir um einen entsprechenden Hinweis. Bei Bekanntwerden von Rechtsverletzungen werden wir derartige Inhalte umgehend entfernen.</p>
      <h3>Datenschutz</h3>
        <p>Die Nutzung unserer Webseite ist in der Regel ohne Angabe personenbezogener Daten möglich. Soweit auf unseren Seiten personenbezogene Daten (beispielsweise Name, Anschrift oder eMail-Adressen) erhoben werden, erfolgt dies, soweit möglich, stets auf freiwilliger Basis. Diese Daten werden ohne Ihre ausdrückliche Zustimmung nicht an Dritte weitergegeben.</p>
        <p>Wir weisen darauf hin, dass die Datenübertragung im Internet (z.B. bei der Kommunikation per E-Mail) Sicherheitslücken aufweisen kann. Ein lückenloser Schutz der Daten vor dem Zugriff durch Dritte ist nicht möglich. </p>
        <p>Der Nutzung von im Rahmen der Impressumspflicht veröffentlichten Kontaktdaten durch Dritte zur Übersendung von nicht ausdrücklich angeforderter Werbung und Informationsmaterialien wird hiermit ausdrücklich widersprochen. Die Betreiber der Seiten behalten sich ausdrücklich rechtliche Schritte im Falle der unverlangten Zusendung von Werbeinformationen, etwa durch Spam-Mails, vor.</p>
    '

    @_imprintBox.append @_imprintClose
    @_imprintBox.append @_imprintText
    @_imprintOverlay.append @_imprintBox


    # event handling
    $(@_imprintClose.elem()).click () =>
      @hideBox()

    $(@_imprintOverlay.elem()).fadeOut 0


  # ============================================================================
  hgInit: (@_hgInstance) ->
    parentDiv = @_hgInstance._config.container
    parentDiv.appendChild @_link.elem()
    parentDiv.appendChild @_imprintOverlay.elem()


  # ============================================================================
  showBox:() ->
    $(@_imprintOverlay.elem()).fadeIn()

  # ============================================================================
  hideBox:() ->
    $(@_imprintOverlay.elem()).fadeOut()

