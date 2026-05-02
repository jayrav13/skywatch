import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://jayrav13.github.io',
  base: '/skywatch',
  integrations: [
    starlight({
      title: 'Skywatch',
      description: 'Aviation situational awareness toolkit — real-time weather, flight tracking, and brief composition from public FAA/NWS/ADS-B data.',
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/jayrav13/skywatch' }
      ],
      sidebar: [
        { label: 'Overview', link: '/' },
        { label: 'Getting started', link: '/getting-started/' },
        { label: 'Claude Code agent', link: '/claude-agent/' },
        {
          label: 'CLI reference',
          items: [
            { label: 'brief', link: '/cli/brief/' },
            { label: 'weather', link: '/cli/weather/' },
            { label: 'nimbus', link: '/cli/nimbus/' },
            { label: 'mayday', link: '/cli/mayday/' },
            { label: 'radar', link: '/cli/radar/' },
            { label: 'agent', link: '/cli/agent/' },
          ],
        },
        {
          label: 'Reference',
          items: [
            { label: 'Brief response shape', link: '/reference/brief-shape/' },
          ],
        },
      ],
    }),
  ],
});
